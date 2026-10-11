package com.nexora.jobs

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import android.graphics.BitmapFactory
import android.net.Uri
import android.content.Context
import okio.BufferedSink
import okhttp3.RequestBody
import org.json.JSONObject
import org.json.JSONArray
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

class JobsRepository(val store: SecureStore) {
 private val client=OkHttpClient.Builder().callTimeout(30,TimeUnit.SECONDS).build()
 private var session=store.read("session")?.let { runCatching { JSONObject(it) }.getOrNull() }
 private val refreshLock=Mutex()
 val userId: String? get() = session?.optJSONObject("user")?.optString("id")?.ifBlank{null}
 val isAdmin: Boolean get()= session?.optJSONObject("user")?.optJSONObject("app_metadata")?.optString("job_portal_role")=="admin"
 private fun save(value: JSONObject?){session=value;store.write("session",value?.toString())}
 private suspend fun raw(path: String,method: String="GET",body: JSONObject?=null,prefer: String?=null,authenticated: Boolean=true): String = withContext(Dispatchers.IO) {
  val request=Request.Builder().url(BackendConfig.URL+path).header("apikey",BackendConfig.PUBLISHABLE_KEY)
  if(authenticated)session?.optString("access_token")?.takeIf{it.isNotBlank()}?.let { request.header("Authorization","Bearer $it") }
  prefer?.let { request.header("Prefer",it) }
  if(method!="GET")request.method(method,(body?.toString()?:"{}").toRequestBody("application/json".toMediaType()))
  client.newCall(request.build()).execute().use { res ->
   val text=res.body?.string().orEmpty()
   if(!res.isSuccessful){val error=runCatching { JSONObject(text) }.getOrNull();val message=listOf("message","msg","error_description","error").map { error?.optString(it).orEmpty() }.firstOrNull { it.isNotBlank() };throw IllegalStateException(message?:"Request failed (${res.code})")}
   text
  }
 }
 private suspend fun ready(){refreshLock.withLock {
  val current=session?:return@withLock
  if(current.optLong("expires_at")>System.currentTimeMillis()/1000+60)return@withLock
  val token=current.optString("refresh_token");if(token.isBlank()){save(null);throw IllegalStateException("Please log in again.")}
  val refreshed=JSONObject(raw("/auth/v1/token?grant_type=refresh_token","POST",JSONObject().put("refresh_token",token),authenticated=false));save(refreshed)
 }}
 suspend fun request(path: String,method: String="GET",body: JSONObject?=null,prefer: String?=null): String { ready();return raw(path,method,body,prefer) }
 suspend fun auth(email: String,password: String,signup: Boolean): Boolean {
  val result=JSONObject(raw(if(signup)"/auth/v1/signup" else "/auth/v1/token?grant_type=password","POST",JSONObject().put("email",email.trim()).put("password",password),authenticated=false))
  if(result.optString("access_token").isBlank())return false
  if(!result.has("expires_at"))result.put("expires_at",System.currentTimeMillis()/1000+result.optLong("expires_in",3600))
  save(result);return true
 }
 suspend fun logout(){try{request("/auth/v1/logout","POST")}catch(_: Exception){};save(null)}
 suspend fun rows(table: String,query: String=""): List<JSONObject> = JSONArray(request("/rest/v1/nexora_job_$table?$query")).objects()
 suspend fun write(table: String,body: JSONObject,id: String?=null): List<JSONObject> = JSONArray(request("/rest/v1/nexora_job_$table"+(id?.let{"?id=eq.$it"}?:""),if(id==null)"POST" else "PATCH",body,"return=representation")).objects().also{check(it.isNotEmpty()){"No record was saved. Check your account access and retry."}}
 suspend fun upsert(table: String,body: JSONObject): List<JSONObject> = JSONArray(request("/rest/v1/nexora_job_$table?on_conflict=user_id","POST",body,"resolution=merge-duplicates,return=representation")).objects().also{check(it.isNotEmpty()){"No profile was saved. Check your account access and retry."}}
 suspend fun categories()=rows("categories","order=sort_order.asc,name.asc&limit=500").map(JobCategory::from)
 suspend fun candidate()=userId?.let{rows("candidates","user_id=eq.$it").firstOrNull()?.let(Candidate::from)}
 suspend fun employer()=userId?.let{rows("employers","user_id=eq.$it").firstOrNull()?.let(Employer::from)}
 private fun overlap(field: String,ids: Set<String>,all: Boolean)=if(ids.isEmpty())"" else "&$field=${if(all)"cs" else "ov"}."+URLEncoder.encode("{${ids.joinToString(",")}}","UTF-8")
 suspend fun jobs(ids: Set<String> = emptySet(),all: Boolean=false)=rows("posts","status=eq.published&moderation_status=eq.approved&or=(application_deadline.is.null,application_deadline.gte.${java.time.LocalDate.now()})&order=created_at.desc&limit=100"+overlap("required_category_ids",ids,all)).map(Job::from)
 suspend fun candidates(ids: Set<String> = emptySet(),all: Boolean=false)=rows("candidates","discoverable=eq.true&order=created_at.desc&limit=100"+overlap("job_profile_category_ids",ids,all)).map(Candidate::from)
 suspend fun profileDraft(): ProfileDraft {
  val c=userId?.let{rows("candidates","user_id=eq.$it").firstOrNull()};val p=userId?.let{rows("candidate_private","user_id=eq.$it").firstOrNull()}?:JSONObject()
  if(c==null)return ProfileDraft(email=session?.optJSONObject("user")?.optString("email").orEmpty())
  fun list(key: String)=c.ids(key).joinToString(", ")
  return ProfileDraft(c.optString("full_name"),c.optString("city"),c.optInt("experience_years").toString(),c.optString("bio"),c.ids("job_profile_category_ids"),c.optBoolean("discoverable"),c.optBoolean("alerts_enabled"),c.optString("state"),p.optString("mobile"),false,p.optString("email"),list("skills"),list("services"),c.optString("qualification"),list("languages"),list("preferred_locations"),c.optInt("expected_salary").toString(),c.optString("availability"),c.optString("employment_history"),p.optString("photo_path"),p.optString("resume_path"),p.ids("portfolio_paths").toList(),c.optString("current_title"))
 }
 suspend fun ownerDraft(): OwnerProfileDraft {val e=userId?.let{rows("employers","user_id=eq.$it").firstOrNull()}?:JSONObject();return OwnerProfileDraft(e.optString("contact_name"),e.optString("salon_name"),e.optString("mobile"),e.optString("email").ifBlank{if(e.has("user_id")) "" else session?.optJSONObject("user")?.optString("email").orEmpty()},e.optString("city"),e.optString("state"),e.optString("description"),e.optString("address"),e.optString("profile_photo_path"))}
 suspend fun saveOwner(d: OwnerProfileDraft){require(d.name.isNotBlank()&&d.salon.isNotBlank()&&d.city.isNotBlank()&&d.state.isNotBlank()){"Name, salon, city and state are required."};require(d.mobile.matches(Regex("\\+?[0-9]{10,15}"))&&(d.email.isBlank()||android.util.Patterns.EMAIL_ADDRESS.matcher(d.email).matches())){"Enter a valid mobile and email."};upsert("employers",JSONObject().put("user_id",userId).put("contact_name",d.name).put("salon_name",d.salon).put("mobile",d.mobile).put("email",d.email).put("city",d.city).put("state",d.state).put("description",d.bio).put("address",d.address).put("profile_photo_path",d.photoPath))}
 suspend fun signedPhoto(path: String): String {val o=JSONObject(request("/storage/v1/object/sign/nexora-job-private/$path","POST",JSONObject().put("expiresIn",600)));return BackendConfig.URL+"/storage/v1"+o.getString("signedURL")}
 suspend fun photoBytes(path: String): ByteArray=withContext(Dispatchers.IO){val url=signedPhoto(path);client.newCall(Request.Builder().url(url).build()).execute().use{require(it.isSuccessful){"Photo could not load. Retry."};it.body!!.bytes()}}
 suspend fun removePhotoObject(path: String){if(path.isBlank())return;request("/storage/v1/object/nexora-job-private","DELETE",JSONObject().put("prefixes",JSONArray(listOf(path))))}
 suspend fun uploadProfileFile(context: Context,uri: Uri,folder: String,onProgress:(Int)->Unit): String=withContext(Dispatchers.IO){
  ready();val type=context.contentResolver.getType(uri).orEmpty();val image=folder!="resume";val types=if(image)setOf("image/jpeg","image/png","image/webp") else setOf("application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document")
  require(type in types){"Choose JPG, PNG or WebP for images, PDF or Word for resume."}
  val bytes=context.contentResolver.openInputStream(uri)?.use{val buffer=java.io.ByteArrayOutputStream();val part=ByteArray(8192);var n=it.read(part);while(n!=-1){require(buffer.size()+n<=5242880){"Maximum file size is 5 MB."};buffer.write(part,0,n);n=it.read(part)};buffer.toByteArray()}?:error("Cannot open this file.")
  require(bytes.isNotEmpty()){"File is empty."};if(image){val bounds=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds);require(bounds.outWidth>0&&bounds.outHeight>0&&bounds.outWidth.toLong()*bounds.outHeight<=40000000){"Choose a valid image up to 40 megapixels."};require(bounds.outMimeType==type){"Image format does not match its file type."}}
  val ext=when(type){"image/png"->"png";"image/webp"->"webp";"image/jpeg"->"jpg";"application/pdf"->"pdf";"application/msword"->"doc";else->"docx"};val path="$userId/$folder/${java.util.UUID.randomUUID()}.$ext"
  val body=object:RequestBody(){override fun contentType()=type.toMediaType();override fun contentLength()=bytes.size.toLong();override fun writeTo(sink:BufferedSink){var offset=0;while(offset<bytes.size){val n=minOf(16384,bytes.size-offset);sink.write(bytes,offset,n);offset+=n;onProgress(offset*100/bytes.size)}}}
  val req=Request.Builder().url(BackendConfig.URL+"/storage/v1/object/nexora-job-private/$path").header("apikey",BackendConfig.PUBLISHABLE_KEY).header("Authorization","Bearer "+session!!.getString("access_token")).post(body).build();client.newCall(req).execute().use{if(!it.isSuccessful)throw IllegalStateException(runCatching{JSONObject(it.body!!.string()).optString("message")}.getOrNull()?:"Upload failed. Retry.")};path
 }
 suspend fun saveCandidate(d: ProfileDraft): Candidate {
  require(d.name.isNotBlank()&&d.city.isNotBlank()){ "Name and city are required." };require(d.ids.isNotEmpty()){ "Select at least one job profile." }
  val years=d.years.toIntOrNull();require(years!=null&&years in 0..70){"Experience must be a whole number from 0 to 70."}
  require(d.consent){"Accept the privacy policy and terms before saving."};require(d.state.isNotBlank()){ "State is required." };require(d.mobile.count{it.isDigit()} in 10..15){"Enter a valid mobile number."}
  val profile=(rows("candidates","user_id=eq.$userId").firstOrNull()?:JSONObject()).put("full_name",d.name.trim()).put("city",d.city.trim()).put("state",d.state.trim()).put("experience_years",years).put("bio",d.bio).put("category_ids",JSONArray(d.ids.toList())).put("discoverable",d.discoverable).put("alerts_enabled",d.alerts).put("consent",true)
  val existing=rows("candidate_private","user_id=eq.$userId").firstOrNull()?:JSONObject()
  require(d.email.isBlank()||android.util.Patterns.EMAIL_ADDRESS.matcher(d.email).matches()){"Enter a valid email."};require(d.mobile.matches(Regex("\\+?[0-9]{10,15}"))){"Enter a valid mobile number."}
  val salary=d.expectedSalary.ifBlank{"0"}.toIntOrNull();require(salary!=null&&salary>=0){"Expected salary must be a non-negative number."}
  fun list(v:String)=JSONArray(v.split(",").map{it.trim()}.filter{it.isNotBlank()}.distinct())
  profile.put("skills",list(d.skills)).put("services",list(d.services)).put("qualification",d.qualification).put("languages",list(d.languages)).put("preferred_locations",list(d.preferredLocations)).put("expected_salary",salary).put("availability",d.availability).put("employment_history",d.employment).put("current_title",d.currentTitle)
  existing.put("mobile",d.mobile).put("email",d.email).put("photo_path",d.photoPath).put("resume_path",d.resumePath).put("portfolio_paths",JSONArray(d.portfolio))
  val response=request("/rest/v1/rpc/nexora_job_save_candidate","POST",JSONObject().put("p_profile",profile).put("p_private",existing))
  return Candidate.from(if(response.trim().startsWith("["))JSONArray(response).getJSONObject(0) else JSONObject(response))
 }
 suspend fun saveEmployer(name: String,city: String,state: String): Employer {
  require(name.isNotBlank()&&city.isNotBlank()&&state.isNotBlank()){"Salon name and city are required."}
  return Employer.from(upsert("employers",JSONObject().put("user_id",userId).put("salon_name",name.trim()).put("city",city.trim()).put("state",state.trim())).first())
 }
 suspend fun saveJob(d: JobDraft,employer: Employer) {
  require(d.primaryCategoryId.isNotBlank()){"Please select the job role you want to hire."};require(d.city.isNotBlank()&&d.state.isNotBlank()&&d.description.isNotBlank()){"City, state and description are required."}
  val category=categories().find{it.id==d.primaryCategoryId}?:error("Invalid Job Title. Refresh categories.");val previous=d.id?.let{rows("posts","id=eq.$it").firstOrNull()?.optString("primary_category_id")};require(category.isActive||previous==category.id){"Choose an active Job Title."}
  val min=d.min.toIntOrNull();val max=d.max.toIntOrNull();require(min!=null&&max!=null&&min>=0&&max>=min){"Enter a valid monthly salary range."}
  require(d.vacancies.toIntOrNull() in 1..1000){"Vacancies must be a whole number from 1 to 1000."}
  val savedId=d.id?:rows("posts","id=eq.${d.submissionId}&employer_id=eq.$userId").firstOrNull()?.getString("id")
  write("posts",JSONObject().put("id",d.id?:d.submissionId).put("vacancies",d.vacancies.toInt()).put("employer_id",userId).put("salon_name",employer.name).put("title",category.name).put("primary_category_id",category.id).put("city",d.city.trim()).put("state",d.state.trim()).put("description",d.description.trim()).put("salary_min",min).put("salary_max",max).put("employment_type",d.type).put("required_category_ids",JSONArray((d.ids+category.id).toList())).put("status",d.status),savedId)
 }
 suspend fun apply(job: Job){require(userId!=null){"Please log in."};require(candidate()!=null){"Create your professional profile first."};write("applications",JSONObject().put("job_id",job.id).put("candidate_id",userId).put("consent_to_share",true))}
 suspend fun invite(candidate: Candidate,job: Job){write("invitations",JSONObject().put("candidate_id",candidate.userId).put("employer_id",userId).put("job_id",job.id))}
}
