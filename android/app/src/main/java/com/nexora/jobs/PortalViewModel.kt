package com.nexora.jobs

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job as CoroutineJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import org.json.JSONObject

data class PortalState(
 val fieldErrors:Map<String,String> = emptyMap(),val validationAttempt:Int=0,val loading: Boolean=false, val error: String?=null, val message: String?=null,
 val categories: List<JobCategory> = emptyList(),val jobs: List<Job> = emptyList(),val candidates: List<Candidate> = emptyList(),
 val candidate: Candidate?=null,val employer: Employer?=null,val loggedIn: Boolean=false,val admin: Boolean=false,
 val screen: String="home",val hindi: Boolean=false,val filterIds: Set<String> = emptySet(),val allMatch: Boolean=false,val query: String="",val city: String="",
 val savedProfile: ProfileDraft=ProfileDraft(),val ownerDraft: OwnerProfileDraft=OwnerProfileDraft(),val savedOwner: OwnerProfileDraft=OwnerProfileDraft(),val photoProgress: Int?=null,val photoError: String?=null,
 val profileDraft: ProfileDraft=ProfileDraft(),val jobDraft: JobDraft=JobDraft(),val employerName: String="",val employerCity: String="",val employerState: String="",
 val myJobs: List<Job> = emptyList(),val applications: List<JSONObject> = emptyList(),val invitations: List<JSONObject> = emptyList(),val alerts: List<Job> = emptyList(),val selectedJob: Job?=null
)
class PortalViewModel(app: Application,private val savedState: SavedStateHandle): AndroidViewModel(app) {
 private val repo=JobsRepository(SecureStore(app))
 private val mutable=MutableStateFlow(PortalState(screen=savedState["screen"]?:"home",hindi=repo.store.read("language")=="hi"))
 val state=mutable.asStateFlow()
 init { refresh() }
 private fun draftKey(kind: String)="${repo.userId?:"guest"}.$kind"
 private var retryTask:(suspend ()->Unit)?=null
 fun retry(){retryTask?.let{run(it)}?:refresh()}
 private fun valid(errors:Map<String,String>):Boolean{mutable.update{it.copy(fieldErrors=errors,validationAttempt=it.validationAttempt+1)};return errors.isEmpty()}
 private fun run(task:suspend ()->Unit){if(mutable.value.loading)return;mutable.update{it.copy(loading=true,error=null,message=null)};retryTask=null;viewModelScope.launch{try{task()}catch(e:Exception){if(e !is IllegalArgumentException)retryTask=task;mutable.update{it.copy(error=e.message?:"Check your connection and retry.")}}finally{mutable.update{it.copy(loading=false)}}}}
 private suspend fun loadAll(){
  val categories=repo.categories();val candidate=repo.candidate();val employer=repo.employer();val s=mutable.value
  val jobs=repo.jobs(s.filterIds,s.allMatch)
  val candidates=if(employer!=null)repo.candidates(s.filterIds,s.allMatch) else emptyList()
  val own=if(employer!=null)repo.rows("posts","employer_id=eq.${repo.userId}&order=created_at.desc").map(Job::from) else emptyList()
  val apps=if(repo.userId!=null)repo.rows("applications","select=*,nexora_job_posts(title,salon_name,employer_id),nexora_job_candidates(full_name,city,job_profile_category_ids)&order=created_at.desc") else emptyList()
  val invites=if(candidate!=null)repo.rows("invitations","candidate_id=eq.${repo.userId}&select=*,nexora_job_posts(title,salon_name)&order=created_at.desc") else emptyList()
  val alerts=if(candidate?.alerts==true)repo.jobs(candidate.jobProfileCategoryIds) else emptyList()
  val savedProfile=repo.profileDraft();val savedOwner=repo.ownerDraft()
  val profileDraft=repo.store.read(draftKey("profile"))?.let{runCatching{val cached=JSONObject(it);val merged=savedProfile.json();cached.keys().forEach{key->merged.put(key,cached.get(key))};ProfileDraft.from(merged)}.getOrNull()}?:savedProfile
  val ownerDraft=repo.store.read(draftKey("owner"))?.let{runCatching{OwnerProfileDraft.from(JSONObject(it))}.getOrNull()}?:savedOwner
  val jobDraft=repo.store.read(draftKey("job"))?.let{runCatching{JobDraft.from(JSONObject(it))}.getOrNull()}?:JobDraft(city=employer?.city.orEmpty(),state=employer?.state.orEmpty())
  mutable.update{it.copy(categories=categories,candidate=candidate,employer=employer,jobs=jobs,candidates=candidates,myJobs=own,applications=apps,invitations=invites,alerts=alerts,loggedIn=repo.userId!=null,admin=repo.isAdmin,savedProfile=savedProfile,savedOwner=savedOwner,ownerDraft=ownerDraft,profileDraft=profileDraft.copy(ids=profileDraft.ids.filter{id->categories.any{it.id==id&&it.isActive}||candidate?.jobProfileCategoryIds?.contains(id)==true}.toSet()),jobDraft=jobDraft.copy(primaryCategoryId=jobDraft.primaryCategoryId.takeIf{id->categories.any{it.id==id&&it.isActive}||own.find{it.id==jobDraft.id}?.primaryCategoryId==id}.orEmpty(),ids=jobDraft.ids.filter{id->categories.any{it.id==id&&it.isActive}||own.find{it.id==jobDraft.id}?.requiredCategoryIds?.contains(id)==true}.toSet()),employerName=employer?.name.orEmpty(),employerCity=employer?.city.orEmpty(),employerState=employer?.state.orEmpty())}
 }
 fun refresh()=run{loadAll()}
 fun go(screen: String){savedState["screen"]=screen;mutable.update{it.copy(screen=screen,error=null,message=null,fieldErrors=emptyMap())}}
 fun language(){mutable.update{it.copy(hindi=!it.hindi)};repo.store.write("language",if(mutable.value.hindi)"hi" else "en")}
 private var filterLoad:CoroutineJob?=null
 fun filter(ids: Set<String>) { mutable.update{it.copy(filterIds=ids)};filterLoad?.cancel();filterLoad=viewModelScope.launch{delay(200);while(mutable.value.loading)delay(100);refresh()} }
 fun allMatch(value: Boolean){mutable.update{it.copy(allMatch=value)}}
 fun query(value: String){mutable.update{it.copy(query=value)}}
 fun city(value: String){mutable.update{it.copy(city=value)}}
 fun myMatches(){mutable.update{it.copy(filterIds=it.candidate?.jobProfileCategoryIds?:emptySet())};refresh()}
 fun profile(d: ProfileDraft){mutable.update{it.copy(profileDraft=d)};repo.store.write(draftKey("profile"),d.json().toString())}
 fun job(d: JobDraft){mutable.update{it.copy(jobDraft=d)};repo.store.write(draftKey("job"),d.json().toString())}
 fun employer(name: String,city: String,state: String=mutable.value.employerState){mutable.update{it.copy(employerName=name,employerCity=city,employerState=state)}}
 fun auth(email: String,password: String,signup: Boolean,employer: Boolean){val errors=linkedMapOf<String,String>();if(!android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches())errors["Email"]="Enter a valid email address.";if(password.length<6)errors["Password"]="Use a password with at least 6 characters.";if(!valid(errors))return;run{
  require(email.contains("@")&&password.length>=6){"Enter a valid email and a password of at least 6 characters."}
  if(!repo.auth(email,password,signup)){mutable.update{it.copy(message="Account created. Confirm your email, then log in to finish your profile.")};return@run}
  loadAll();go(if(signup||(mutable.value.candidate==null&&mutable.value.employer==null))if(employer)"employer" else "profile" else "dashboard")
 }
 }
 fun logout()=run{repo.logout();mutable.value=PortalState(categories=mutable.value.categories,hindi=mutable.value.hindi);savedState["screen"]="home";loadAll()}
 fun ownerProfile(d: OwnerProfileDraft){mutable.update{it.copy(ownerDraft=d)};repo.store.write(draftKey("owner"),d.json().toString())}
 suspend fun photoBytes(path:String)=repo.photoBytes(path)
 suspend fun fileUrl(path:String)=repo.signedPhoto(path)
 fun fileError(message:String){mutable.update{it.copy(error=message)}}
 private var retryFile: Triple<Uri,Boolean,String>?=null
 fun uploadFile(uri:Uri,owner:Boolean=false,folder:String="photo"){
  if(mutable.value.loading)return;retryFile=Triple(uri,owner,folder)
  run{mutable.update{it.copy(photoProgress=0,photoError=null)}
   try{val path=repo.uploadProfileFile(getApplication(),uri,folder){p->mutable.update{it.copy(photoProgress=p)}}
    if(owner)ownerProfile(mutable.value.ownerDraft.copy(photoPath=path)) else {val d=mutable.value.profileDraft;profile(when(folder){"resume"->d.copy(resumePath=path);"portfolio"->d.copy(portfolio=(d.portfolio+path).distinct().take(6));else->d.copy(photoPath=path)})}
    retryFile=null;mutable.update{it.copy(message="Upload complete. Save profile to apply the change.")}
   }catch(e:Exception){mutable.update{it.copy(photoError=e.message?:"Upload failed. Retry.")}}
   finally{mutable.update{it.copy(photoProgress=null)}}
  }
 }
 fun retryPhoto(){retryFile?.let{uploadFile(it.first,it.second,it.third)}}
 fun removePhoto(owner:Boolean){if(owner)ownerProfile(mutable.value.ownerDraft.copy(photoPath="")) else profile(mutable.value.profileDraft.copy(photoPath=""));mutable.update{it.copy(photoError=null)}}
 fun cancelProfile(owner:Boolean)=run{repo.store.write(draftKey(if(owner)"owner" else "profile"),null);loadAll();go("dashboard");mutable.update{it.copy(photoError=null)}}
 fun saveProfile(){if(!valid(profileErrors(mutable.value.profileDraft)))return;run{repo.saveCandidate(mutable.value.profileDraft);repo.store.write(draftKey("profile"),null);loadAll();go("dashboard");mutable.update{it.copy(message="Professional profile saved.",photoError=null)}}}
 fun saveEmployer(){if(!valid(ownerErrors(mutable.value.ownerDraft)))return;run{repo.saveOwner(mutable.value.ownerDraft);repo.store.write(draftKey("owner"),null);loadAll();go("dashboard");mutable.update{it.copy(message="Salon owner profile saved.",photoError=null)}}}
 fun saveJob(){if(!valid(jobErrors(mutable.value.jobDraft)))return;run{repo.saveJob(mutable.value.jobDraft,mutable.value.employer?:error("Create an employer profile first."));repo.store.write(draftKey("job"),null);loadAll();go("dashboard");mutable.update{it.copy(message="Job saved. Published submissions are reviewed before public discovery.")}}}
 fun newJob(){job(JobDraft(city=mutable.value.employer?.city.orEmpty(),state=mutable.value.employer?.state.orEmpty()));go(if(!mutable.value.loggedIn)"auth" else if(mutable.value.employer==null)"employer" else "post")}
 fun editJob(j: Job)=run{if(j.status=="closed")return@run;val vacancies=repo.rows("posts","id=eq.${j.id}").firstOrNull()?.optInt("vacancies",1)?.toString()?:"1";job(JobDraft(j.id,j.title,j.city,j.minSalary.toString(),j.maxSalary.toString(),j.description,j.type,j.requiredCategoryIds,j.status,j.state,j.primaryCategoryId,vacancies));go("post")}
 fun detail(j: Job){mutable.update{it.copy(selectedJob=j)};go("detail")}
 fun detail(id: String)=run{val row=repo.rows("posts","id=eq.$id").firstOrNull()?:error("This job is unavailable.");detail(Job.from(row))}
 fun apply(j: Job)=run{repo.apply(j);loadAll();mutable.update{it.copy(message="Application sent. View its status in your dashboard.")}}
 fun closeJob(j: Job)=run{repo.write("posts",JSONObject().put("status","closed"),j.id);loadAll()}
 fun withdraw(id: String)=run{repo.write("applications",JSONObject().put("status","withdrawn"),id);loadAll()}
 fun applicationStatus(id: String,status: String)=run{repo.write("applications",JSONObject().put("status",status),id);loadAll()}
 fun invite(c: Candidate,j: Job)=run{repo.invite(c,j);mutable.update{it.copy(message="Invitation sent to the candidate’s Nexora inbox.")}}
 fun category(id: String?,name: String,hindi: String,slug: String,order: String,active: Boolean)=run{
  require(repo.isAdmin){"Administrator access required."};require(name.isNotBlank()&&hindi.isNotBlank()){"Both labels are required."}
  repo.write("categories",JSONObject().put("name",name.trim()).put("name_hi",hindi.trim()).put("slug",slug.trim()).put("sort_order",order.toIntOrNull()?:0).put("is_active",active),id);loadAll();go("dashboard")
 }
}
