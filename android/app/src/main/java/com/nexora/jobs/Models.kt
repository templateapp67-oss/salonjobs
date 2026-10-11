package com.nexora.jobs

import org.json.JSONObject
import org.json.JSONArray

fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
fun JSONObject.ids(key: String): Set<String> = optJSONArray(key)?.let { a -> (0 until a.length()).map { a.getString(it) }.toSet() } ?: emptySet()
data class JobCategory(val id: String, val name: String, val nameHi: String, val isActive: Boolean, val sortOrder: Int, val slug: String="") {
 fun label(hindi: Boolean) = if (hindi) nameHi.ifBlank { name } else name
 companion object { fun from(o: JSONObject) = JobCategory(o.getString("id"),o.getString("name"),o.optString("name_hi"),o.getBoolean("is_active"),o.getInt("sort_order"),o.getString("slug")) }
}
data class Candidate(val userId: String, val name: String, val city: String, val years: Int, val bio: String, val jobProfileCategoryIds: Set<String>, val discoverable: Boolean, val alerts: Boolean, val state: String="") {
 companion object { fun from(o: JSONObject) = Candidate(o.getString("user_id"),o.getString("full_name"),o.getString("city"),o.getInt("experience_years"),o.getString("bio"),o.ids("job_profile_category_ids"),o.getBoolean("discoverable"),o.getBoolean("alerts_enabled"),o.optString("state")) }
}
data class Employer(val userId: String, val name: String, val city: String,val state: String="") {
 companion object { fun from(o: JSONObject) = Employer(o.getString("user_id"),o.getString("salon_name"),o.getString("city"),o.optString("state")) }
}
data class Job(val id: String, val ownerId: String, val title: String, val salon: String, val city: String, val description: String, val minSalary: Int, val maxSalary: Int, val type: String, val requiredCategoryIds: Set<String>, val status: String,val state: String="",val requiresResume: Boolean=false,val screeningQuestions: Set<String> = emptySet(),val moderation: String="pending",val primaryCategoryId:String="",val vacancies:String="1",val submissionId:String=java.util.UUID.randomUUID().toString()) {
 companion object { fun from(o: JSONObject) = Job(o.getString("id"),o.getString("employer_id"),o.getString("title"),o.getString("salon_name"),o.getString("city"),o.getString("description"),o.getInt("salary_min"),o.getInt("salary_max"),o.getString("employment_type"),o.ids("required_category_ids"),o.getString("status"),o.optString("state"),o.optBoolean("requires_resume"),o.ids("screening_questions"),o.optString("moderation_status","pending"),o.optString("primary_category_id").takeUnless{it=="null"}.orEmpty()) }
}
data class ProfileDraft(val name: String="", val city: String="", val years: String="0", val bio: String="", val ids: Set<String> = emptySet(), val discoverable: Boolean=false, val alerts: Boolean=false,val state: String="",val mobile: String="",val consent: Boolean=false,
 val email: String="",val skills: String="",val services: String="",val qualification: String="",val languages: String="",val preferredLocations: String="",val expectedSalary: String="",val availability: String="",val employment: String="",val photoPath: String="",val resumePath: String="",val portfolio: List<String> = emptyList(),val currentTitle: String="") {
 fun json() = JSONObject().put("name",name).put("city",city).put("years",years).put("bio",bio).put("ids",JSONArray(ids.toList())).put("discoverable",discoverable).put("alerts",alerts).put("state",state).put("mobile",mobile).put("consent",consent).put("email",email).put("skills",skills).put("services",services).put("qualification",qualification).put("languages",languages).put("preferredLocations",preferredLocations).put("expectedSalary",expectedSalary).put("availability",availability).put("employment",employment).put("photoPath",photoPath).put("resumePath",resumePath).put("portfolio",JSONArray(portfolio)).put("currentTitle",currentTitle)
 companion object { fun from(o: JSONObject) = ProfileDraft(o.optString("name"),o.optString("city"),o.optString("years","0"),o.optString("bio"),o.ids("ids"),o.optBoolean("discoverable"),o.optBoolean("alerts"),o.optString("state"),o.optString("mobile"),o.optBoolean("consent"),o.optString("email"),o.optString("skills"),o.optString("services"),o.optString("qualification"),o.optString("languages"),o.optString("preferredLocations"),o.optString("expectedSalary"),o.optString("availability"),o.optString("employment"),o.optString("photoPath"),o.optString("resumePath"),o.ids("portfolio").toList(),o.optString("currentTitle")) }
 fun missing(): List<String> = listOf("Full name" to name.isNotBlank(),"Photo" to photoPath.isNotBlank(),"Mobile" to mobile.isNotBlank(),"Email" to email.isNotBlank(),"City" to city.isNotBlank(),"State" to state.isNotBlank(),"Introduction" to bio.isNotBlank(),"Skills" to skills.isNotBlank(),"Experience" to (years.toIntOrNull()!=null),"Qualification" to qualification.isNotBlank(),"Languages" to languages.isNotBlank(),"Preferred location" to preferredLocations.isNotBlank(),"Expected salary" to ((expectedSalary.toIntOrNull()?:0)>0),"Joining availability" to availability.isNotBlank()).filter{!it.second}.map{it.first}
 fun completion()=((14-missing().size)*100.0/14).toInt()
}
data class OwnerProfileDraft(val name: String="",val salon: String="",val mobile: String="",val email: String="",val city: String="",val state: String="",val bio: String="",val address: String="",val photoPath: String="") {
 fun json()=JSONObject().put("name",name).put("salon",salon).put("mobile",mobile).put("email",email).put("city",city).put("state",state).put("bio",bio).put("address",address).put("photoPath",photoPath)
 companion object {fun from(o: JSONObject)=OwnerProfileDraft(o.optString("name"),o.optString("salon"),o.optString("mobile"),o.optString("email"),o.optString("city"),o.optString("state"),o.optString("bio"),o.optString("address"),o.optString("photoPath"))}
 fun missing()=listOf("Full name" to name.isNotBlank(),"Photo" to photoPath.isNotBlank(),"Mobile" to mobile.isNotBlank(),"Email" to email.isNotBlank(),"City" to city.isNotBlank(),"State" to state.isNotBlank(),"Salon" to salon.isNotBlank(),"Introduction" to bio.isNotBlank(),"Address" to address.isNotBlank()).filter{!it.second}.map{it.first}
 fun completion()=((9-missing().size)*100.0/9).toInt()
}
data class JobDraft(val id: String?=null, val title: String="", val city: String="", val min: String="", val max: String="", val description: String="", val type: String="Full-time", val ids: Set<String> = emptySet(), val status: String="published",val state: String="",val primaryCategoryId:String="",val vacancies:String="1",val submissionId:String=java.util.UUID.randomUUID().toString()) {
 fun json() = JSONObject().put("id",id).put("title",title).put("city",city).put("min",min).put("max",max).put("description",description).put("type",type).put("ids",JSONArray(ids.toList())).put("status",status).put("state",state).put("primaryCategoryId",primaryCategoryId).put("vacancies",vacancies).put("submissionId",submissionId)
 companion object { fun from(o: JSONObject) = JobDraft(if(o.isNull("id"))null else o.optString("id").ifBlank{null},o.optString("title"),o.optString("city"),o.optString("min"),o.optString("max"),o.optString("description"),o.optString("type","Full-time"),o.ids("ids"),o.optString("status","published"),o.optString("state"),o.optString("primaryCategoryId"),o.optString("vacancies","1"),o.optString("submissionId").ifBlank{java.util.UUID.randomUUID().toString()}) }
}
