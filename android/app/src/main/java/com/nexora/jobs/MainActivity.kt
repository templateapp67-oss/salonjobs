package com.nexora.jobs

import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.layout.ContentScale
import android.os.Bundle
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.json.JSONObject

private val Purple=Color(0xFF77198D)
class MainActivity: ComponentActivity(){override fun onCreate(savedInstanceState: Bundle?){super.onCreate(savedInstanceState);setContent {
 MaterialTheme(colorScheme=lightColorScheme(primary=Purple,primaryContainer=Color(0xFFF0E8FC),secondary=Color(0xFF426B27),background=Color(0xFFFAF8FE))){Portal()}
}}}
@Composable private fun Input(label:String,value:String,onChange:(String)->Unit,multiline:Boolean=false){GuidedField(label,value,onChange,multiline)}
@Composable private fun Action(text: String,loading: Boolean=false,onClick: ()->Unit){Button(onClick,enabled=!loading,modifier=Modifier.fillMaxWidth().heightIn(min=50.dp),shape=RoundedCornerShape(12.dp)){Text(text)}}
@Composable private fun Section(title: String,content: @Composable ColumnScope.()->Unit){OutlinedCard(Modifier.fillMaxWidth(),shape=RoundedCornerShape(18.dp)){Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text(title,style=MaterialTheme.typography.titleLarge);content()}}}
@OptIn(ExperimentalLayoutApi::class)
@Composable private fun Tags(ids: Set<String>,s: PortalState){FlowRow(horizontalArrangement=Arrangement.spacedBy(6.dp),verticalArrangement=Arrangement.spacedBy(4.dp)){ids.forEach{id->Surface(color=MaterialTheme.colorScheme.primaryContainer,shape=RoundedCornerShape(7.dp)){Text(s.categories.find{it.id==id}?.label(s.hindi)?:"Archived profile",Modifier.padding(8.dp),style=MaterialTheme.typography.labelMedium,color=Purple)}}}}
private fun displayJobTitle(j:Job,s:PortalState)=s.categories.find{it.id==j.primaryCategoryId}?.name?:j.title
@Composable private fun JobCard(j: Job,s: PortalState,vm: PortalViewModel){OutlinedCard(Modifier.fillMaxWidth(),shape=RoundedCornerShape(16.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Text(displayJobTitle(j,s),style=MaterialTheme.typography.titleLarge);Text("${j.salon} · ${j.city}",style=MaterialTheme.typography.bodyMedium);Text("${j.type} · ₹${j.minSalary}–${j.maxSalary} / month");Tags(j.requiredCategoryIds,s);TextButton({vm.detail(j)}){Text(if(s.hindi)"जॉब देखें ↗" else "View job ↗")}}}}
@OptIn(ExperimentalMaterial3Api::class,ExperimentalLayoutApi::class)
@Composable fun Portal(vm: PortalViewModel=viewModel()) {
 val s by vm.state.collectAsStateWithLifecycle()
 val context=LocalContext.current
 var applyConsent by rememberSaveable(s.selectedJob?.id){mutableStateOf(false)}
 val tr={en: String,hi: String->if(s.hindi)hi else en}
 var inviteCandidate by remember{mutableStateOf<Candidate?>(null)}
 var closeJob by remember{mutableStateOf<Job?>(null)}
 CompositionLocalProvider(LocalFormContext provides FormContext(s.screen,s.hindi,s.fieldErrors,s.validationAttempt)){
 Scaffold(topBar={TopAppBar(title={Image(painterResource(R.drawable.nexora_logo),contentDescription="Nexora Salon Jobs",modifier=Modifier.width(150.dp).height(50.dp),contentScale=ContentScale.Fit)},actions={TextButton({vm.language()}){Text(if(s.hindi)"EN" else "हिंदी")};TextButton({vm.go(if(s.loggedIn)"dashboard" else "auth")}){Text(if(s.loggedIn)tr("Account","खाता") else tr("Log in","लॉग इन"))}})},bottomBar={NavigationBar {
  listOf(Triple("home","⌂",tr("Home","होम")),Triple("jobs","⌕",tr("Jobs","जॉब")),Triple("talent","♧",tr("Talent","टीम")),Triple("dashboard","◉",tr("Profile","प्रोफ़ाइल"))).forEach{(screen,icon,label)->NavigationBarItem(selected=s.screen==screen,onClick={vm.go(screen)},icon={Text(icon)},label={Text(label)})}
 }}){padding->Column(Modifier.padding(padding).fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){
  if(s.loading)LinearProgressIndicator(Modifier.fillMaxWidth())
  s.error?.let{Surface(color=MaterialTheme.colorScheme.errorContainer,shape=RoundedCornerShape(10.dp)){Column(Modifier.padding(14.dp)){Text(it,color=MaterialTheme.colorScheme.error);TextButton({vm.retry()}){Text(tr("Retry","फिर प्रयास करें"))}}}}
  s.message?.let{Text(it,color=MaterialTheme.colorScheme.secondary)}
  when(s.screen){
   "home"->{
    Text(tr("YOUR NEXT PROFESSIONAL CHAPTER","आपके करियर का अगला अध्याय"),style=MaterialTheme.typography.labelMedium,color=Purple)
    Text(tr("Your talent.\nYour next chapter.","आपका हुनर।\nआपका अगला अवसर।"),style=MaterialTheme.typography.headlineLarge)
    Text(tr("Find a role that fits your skills, or the talent your salon has been waiting for.","अपने हुनर के लिए सही जॉब या सैलून के लिए सही टीम खोजें।"))
    Action(tr("Find my next job ↗","मेरा अगला जॉब ↗")){vm.go("jobs")}
    OutlinedButton({vm.go(if(s.loggedIn)"profile" else "auth")},Modifier.fillMaxWidth()){Text(tr("Build my profile +","प्रोफ़ाइल बनाएँ +"))}
    Section(tr("Find your kind of work","अपने हुनर का काम")){s.categories.filter{it.isActive}.take(8).forEach{c->TextButton({vm.filter(setOf(c.id));vm.go("jobs")}){Text(c.label(s.hindi)+" ↗")}}}
    Section(tr("Great teams. Beautiful businesses.","बेहतरीन टीम। सफल सैलून।")){Text(tr("Post your vacancy and discover professionals by the skills you need.","जॉब पोस्ट करें और हुनर से प्रोफेशनल्स खोजें।"));Action(tr("Start hiring ↗","हायरिंग शुरू करें ↗")){vm.newJob()}}
    Text(tr("Fresh opportunities","नए अवसर"),style=MaterialTheme.typography.titleLarge)
    if(s.jobs.isEmpty())Text(tr("No jobs yet. Salon owners can publish their first vacancy today.","अभी जॉब नहीं हैं। सैलून मालिक अपनी पहली नौकरी पोस्ट करें।")) else s.jobs.take(3).forEach{JobCard(it,s,vm)}
   }
   "auth"->{
    var email by rememberSaveable{mutableStateOf("")};var password by remember{mutableStateOf("")};var signup by rememberSaveable{mutableStateOf(false)};var employer by rememberSaveable{mutableStateOf(false)}
    Text(if(signup)tr("Your next chapter starts here","आपका अगला अध्याय") else tr("Welcome back","फिर से स्वागत है"),style=MaterialTheme.typography.headlineMedium)
    Input(tr("Email address","ईमेल"),email,{email=it});OutlinedTextField(password,{password=it},label={Text(tr("Password · 6+ characters","पासवर्ड · 6+ अक्षर"))},visualTransformation=PasswordVisualTransformation(),keyboardOptions=androidx.compose.foundation.text.KeyboardOptions(keyboardType=androidx.compose.ui.text.input.KeyboardType.Password),singleLine=true,isError=s.fieldErrors.containsKey("Password"),supportingText={Text(s.fieldErrors["Password"]?:tr("Required · Use at least 6 characters.","ज़रूरी · कम से कम 6 अक्षर रखें।"))},modifier=Modifier.fillMaxWidth())
    Row(verticalAlignment=Alignment.CenterVertically){Checkbox(employer,{employer=it});Text(tr("I’m a salon employer","मैं सैलून नियोक्ता हूँ"))}
    Action(if(signup)tr("Create account","खाता बनाएँ") else tr("Log in","लॉग इन"),s.loading){vm.auth(email,password,signup,employer)}
    TextButton({signup=!signup}){Text(if(signup)tr("Already have an account? Log in","पहले से खाता है? लॉग इन करें") else tr("New to Nexora? Create an account","नया खाता बनाएँ"))}
    Text(tr("After signing in, complete your profile and select your professional categories.","लॉग इन के बाद अपना प्रोफ़ाइल पूरा करें और जॉब श्रेणियाँ चुनें।"),style=MaterialTheme.typography.bodySmall)
   }
   "profile","employer"->{if(!s.loggedIn){Action("Log in to edit profile"){vm.go("auth")}}else ProfileEditor(s,vm,s.screen=="employer")}
   "post"->{
    val d=s.jobDraft;var validate by rememberSaveable{mutableStateOf(false)}
    Text(if(d.id==null)tr("Find your next team member","अपनी अगली टीम खोजें") else tr("Edit job","जॉब संपादित करें"),style=MaterialTheme.typography.headlineMedium)
    JobTitleSelection(s.categories,d.primaryCategoryId,{id->vm.job(d.copy(primaryCategoryId=id,title=s.categories.find{it.id==id}?.name.orEmpty(),ids=(d.ids-d.primaryCategoryId)+id))},loading=s.loading&&s.categories.isEmpty(),showValidation=validate||s.fieldErrors.containsKey("Job Title"),onRetry={vm.refresh()},historicalId=s.myJobs.find{it.id==d.id}?.primaryCategoryId.orEmpty());Input(tr("City","शहर"),d.city,{vm.job(d.copy(city=it))})
    Input(tr("State","राज्य"),d.state,{vm.job(d.copy(state=it))})
    Input(tr("Monthly salary from (₹)","मासिक वेतन से (₹)"),d.min,{vm.job(d.copy(min=it))});Input(tr("Monthly salary to (₹)","मासिक वेतन तक (₹)"),d.max,{vm.job(d.copy(max=it))})
    JobProfileSelection(s.categories.filter{it.id!=d.primaryCategoryId},d.ids-d.primaryCategoryId,{ids->vm.job(d.copy(ids=ids+setOf(d.primaryCategoryId).filter{it.isNotBlank()}))},title=tr("Required Profiles · Optional","अतिरिक्त प्रोफ़ाइल · वैकल्पिक"),hindi=s.hindi,historicalIds=s.myJobs.find{it.id==d.id}?.requiredCategoryIds?:emptySet())
    Text(tr("Select additional relevant profiles only if needed. The primary title is included automatically.","अतिरिक्त भूमिकाएँ केवल ज़रूरत हो तभी चुनें।"))
    Input("Number of vacancies",d.vacancies,{vm.job(d.copy(vacancies=it))})
    Text(tr("Employment type · Required: choose your working arrangement.","रोजगार का प्रकार · ज़रूरी।"))
    FlowRow(horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("Full-time","Part-time","Contract","Internship","Freelance").forEach{type->FilterChip(selected=d.type==type,onClick={vm.job(d.copy(type=type))},label={Text(type)})}}
    Input(tr("Responsibilities & benefits","काम, ज़िम्मेदारियाँ और लाभ"),d.description,{vm.job(d.copy(description=it))},true)
    Row(verticalAlignment=Alignment.CenterVertically){Checkbox(d.status=="published",{vm.job(d.copy(status=if(it)"published" else "draft"))});Text(tr("Submit for publication review","प्रकाशन की समीक्षा के लिए भेजें"))}
    Action(tr("Save job ↗","जॉब सहेजें ↗"),s.loading){validate=true;vm.saveJob()}
   }
   "jobs","talent"->{
    val talent=s.screen=="talent"
    Text(if(talent)tr("Meet your next team member","अपनी अगली टीम खोजें") else tr("Find your next opportunity","अपना अगला अवसर खोजें"),style=MaterialTheme.typography.headlineMedium)
    if(talent&&s.employer==null){Text(tr("Create an employer profile to browse the opt-in talent directory.","प्रोफेशनल्स खोजने के लिए नियोक्ता प्रोफ़ाइल बनाएँ।"));Action(tr("Create employer profile","नियोक्ता प्रोफ़ाइल बनाएँ")){vm.go(if(s.loggedIn)"employer" else "auth")}}else{
     if(!talent)Input(tr("Job title or salon","जॉब या सैलून"),s.query,{vm.query(it)})
     Input(tr("City (optional)","शहर (वैकल्पिक)"),s.city,{vm.city(it)})
     JobProfileSelection(s.categories,s.filterIds,{vm.filter(it)},hindi=s.hindi,allowSelectAll=true)
     Row(verticalAlignment=Alignment.CenterVertically){Checkbox(s.allMatch,{vm.allMatch(it)});Text(tr("Match all selected categories","सभी चयनित श्रेणियाँ मिलें"))}
     Action(tr("Apply filters","फ़िल्टर लगाएँ"),s.loading){vm.refresh()}
     if(!talent&&s.candidate!=null)TextButton({vm.myMatches()}){Text(tr("Use my professional profiles","मेरी प्रोफ़ाइल से खोजें"))}
     if(talent){val result=s.candidates.filter{it.city.contains(s.city,true)&&(it.name+" "+it.bio).contains(s.query,true)};Text("${result.size} ${tr("professionals","प्रोफेशनल्स")}");result.forEach{c->Section(c.name){Text("${c.city} · ${c.years} years experience");Tags(c.jobProfileCategoryIds,s);Text(c.bio);OutlinedButton({inviteCandidate=c},enabled=!s.loading){Text(tr("Invite to apply ↗","आवेदन आमंत्रण ↗"))}}};if(result.isEmpty())Text(tr("No matching professionals. Try different filters.","कोई मैच नहीं। दूसरे फ़िल्टर चुनें।"))}
     else{val result=s.jobs.filter{it.city.contains(s.city,true)&&(it.title+it.salon+it.description).contains(s.query,true)};Text("${result.size} ${tr("opportunities","अवसर")}");result.forEach{JobCard(it,s,vm)};if(result.isEmpty())Text(tr("No matching jobs yet. Try different filters.","अभी कोई मैच नहीं। दूसरे फ़िल्टर चुनें।"))}
    }
   }
   "detail"->{s.selectedJob?.let{j->
    Text(displayJobTitle(j,s),style=MaterialTheme.typography.headlineMedium);Text("${j.salon} · ${j.city}");Text("₹${j.minSalary}–${j.maxSalary} / month · ${j.type}");Tags(j.requiredCategoryIds,s);Text(j.description)
    if(s.myJobs.any{it.id==j.id}){if(j.status!="closed")Action(tr("Edit job","जॉब संपादित करें")){vm.editJob(j)}}else if(j.status=="published"&&j.moderation=="approved"){
     if(!s.loggedIn)Action(tr("Log in to apply","आवेदन के लिए लॉग इन करें")){vm.go("auth")}
     else if(s.candidate==null)Action(tr("Complete profile to apply","आवेदन के लिए प्रोफ़ाइल पूरा करें")){vm.go("profile")}
     else{val applied=s.applications.any{it.optString("job_id")==j.id};if(applied)Text(tr("You have already applied to this job.","आपने इस जॉब के लिए आवेदन किया है।"))else if(j.requiresResume||j.screeningQuestions.isNotEmpty()){Text(tr("This job needs a resume or screening answers. Complete your application on the website.","इस जॉब में रिज़्यूमे या सवालों के जवाब चाहिए। वेबसाइट पर आवेदन पूरा करें।"));Action(tr("Complete application ↗","आवेदन पूरा करें ↗")){context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://nexora-salon-job-portal.templateapp67.chatgpt.site/?job="+j.id)))}}else{Text(tr("Your saved profile and contact details will be shared. Confirm consent below before applying.","सहेजा प्रोफ़ाइल और संपर्क साझा होगा। नीचे सहमति दें।"));Row(verticalAlignment=Alignment.CenterVertically){Checkbox(applyConsent,{applyConsent=it});Text(tr("I consent to share my application and contact details with this salon.","मैं इस सैलून के साथ आवेदन और संपर्क विवरण साझा करने की अनुमति देता/देती हूँ।"),Modifier.weight(1f))};Button(onClick={vm.apply(j)},enabled=applyConsent&&!s.loading,modifier=Modifier.fillMaxWidth()){Text(tr("Apply now ↗","आवेदन करें ↗"))}}}
    }else Text(tr("This job is closed.","यह जॉब बंद है।"))
   }?:Text("Select a job to view its details.")}
   "dashboard"->{if(!s.loggedIn){Text(tr("Your career, in one place.","आपका करियर, एक जगह।"),style=MaterialTheme.typography.headlineMedium);Action(tr("Log in","लॉग इन")){vm.go("auth")}}else{
    Text(tr("Your Nexora","आपका Nexora"),style=MaterialTheme.typography.headlineMedium)
    Section(tr("Professional profile","प्रोफेशनल प्रोफ़ाइल")){s.candidate?.let{ProfilePhoto(s.savedProfile.photoPath,it.name,vm);SavedCompletion(s.savedProfile.completion(),s.savedProfile.missing());Text("${it.name} · ${it.city}");Tags(it.jobProfileCategoryIds,s)};Action(tr("Create / edit profile","प्रोफ़ाइल बनाएँ / बदलें")){vm.go("profile")}}
    Section(tr("Salon employer","सैलून नियोक्ता")){if(s.employer!=null){ProfilePhoto(s.savedOwner.photoPath,s.savedOwner.name,vm);SavedCompletion(s.savedOwner.completion(),s.savedOwner.missing())};Text(s.employer?.name?:tr("Build your dream team.","अपनी टीम बनाएँ।"));TextButton({vm.go("employer")}){Text(tr("Create / edit salon","सैलून बनाएँ / बदलें"))};Action(tr("Post a job +","जॉब पोस्ट करें +")){vm.newJob()}}
    Section(tr("My applications","मेरे आवेदन")){val own=s.applications.filter{it.optString("candidate_id")==s.candidate?.userId};if(own.isEmpty())Text("No applications yet.");own.forEach{a->Text(a.optJSONObject("nexora_job_posts")?.optString("title")?:"Archived job");Text("Status: ${a.optString("status")}");if(a.optString("status")=="applied")TextButton({vm.withdraw(a.getString("id"))},enabled=!s.loading){Text("Withdraw")}}}
    if(s.employer!=null){Section(tr("My jobs","मेरी नौकरियाँ")){if(s.myJobs.isEmpty())Text("No jobs posted yet.");s.myJobs.forEach{j->Text("${displayJobTitle(j,s)} · ${j.status}");Tags(j.requiredCategoryIds,s);if(j.status!="closed")Row{TextButton({vm.editJob(j)}){Text("Edit")};TextButton({closeJob=j}){Text("Close")}}}}
     Section(tr("Applicants","आवेदक")){val applicants=s.applications.filter{it.optJSONObject("nexora_job_posts")?.optString("employer_id")==s.employer?.userId};if(applicants.isEmpty())Text("No applicants yet.");applicants.forEach{a->Text(a.optJSONObject("nexora_job_candidates")?.optString("full_name")?:"Candidate");Text("${a.optJSONObject("nexora_job_posts")?.optString("title")} · ${a.optString("status")}");Tags(a.optJSONObject("nexora_job_candidates")?.ids("job_profile_category_ids")?:emptySet(),s);if(a.optString("status") in listOf("applied","shortlisted"))FlowRow{listOf("shortlisted","hired","rejected").forEach{status->TextButton({vm.applicationStatus(a.getString("id"),status)},enabled=!s.loading){Text(status)}}}}}}
    Section(tr("Invitations","आमंत्रण")){if(s.invitations.isEmpty())Text("No invitations yet. Enable discoverability to receive invitations.");s.invitations.forEach{i->Text(i.optJSONObject("nexora_job_posts")?.optString("title")?:"Archived job");TextButton({vm.detail(i.getString("job_id"))}){Text("View & apply ↗")}}}
    Text(tr("In-app job alerts","ऐप में जॉब अलर्ट"),style=MaterialTheme.typography.titleLarge)
    if(s.candidate?.alerts!=true)Text("Enable alerts in your professional profile.")else if(s.alerts.isEmpty())Text("No matching roles yet.")else s.alerts.forEach{JobCard(it,s,vm)}
    if(s.admin)Action(tr("Manage categories","श्रेणियाँ प्रबंधित करें")){vm.go("admin")}
    OutlinedButton({vm.logout()},enabled=!s.loading,modifier=Modifier.fillMaxWidth()){Text(tr("Log out","लॉग आउट"))}
   }}
   "admin"->{if(s.admin)CategoryAdmin(s,vm)else Text("Administrator access required.")}
  }
  Spacer(Modifier.height(24.dp))
 }}
 inviteCandidate?.let{c->AlertDialog(onDismissRequest={inviteCandidate=null},title={Text("Invite ${c.name}")},text={Column(Modifier.heightIn(max=350.dp).verticalScroll(rememberScrollState())){val open=s.myJobs.filter{it.status=="published"};if(open.isEmpty())Text("Publish a job before inviting candidates.");open.forEach{j->TextButton({vm.invite(c,j);inviteCandidate=null}){Text(j.title+" ↗")}}}},confirmButton={TextButton({inviteCandidate=null}){Text("Done")}})}
 closeJob?.let{j->AlertDialog(onDismissRequest={closeJob=null},title={Text("Close this job?")},text={Text("It will stop accepting applications and cannot be edited after closing.")},confirmButton={TextButton({vm.closeJob(j);closeJob=null}){Text("Close job")}},dismissButton={TextButton({closeJob=null}){Text("Keep open")}})}
}
}

@Composable private fun CategoryAdmin(s: PortalState,vm: PortalViewModel){
 var editing by remember{mutableStateOf<JobCategory?>(null)};var name by rememberSaveable{mutableStateOf("")};var hindi by rememberSaveable{mutableStateOf("")};var slug by rememberSaveable{mutableStateOf("")};var order by rememberSaveable{mutableStateOf("0")};var active by rememberSaveable{mutableStateOf(true)}
 Column(verticalArrangement=Arrangement.spacedBy(12.dp)){
  Text("Professional categories",style=MaterialTheme.typography.headlineMedium);Text("Deactivate instead of deleting to preserve historical records.")
  Input("English label",name,{name=it});Input("Hindi label",hindi,{hindi=it});Input("Slug",slug,{slug=it});Input("Sort order",order,{order=it});Row(verticalAlignment=Alignment.CenterVertically){Checkbox(active,{active=it});Text("Active and selectable")}
  Action(if(editing==null)"Add category" else "Save changes",s.loading){vm.category(editing?.id,name,hindi,slug,order,active)}
  TextButton({editing=null;name="";hindi="";slug="";order=s.categories.size.toString();active=true}){Text("New category")}
  s.categories.forEach{c->OutlinedButton({editing=c;name=c.name;hindi=c.nameHi;slug=c.slug;order=c.sortOrder.toString();active=c.isActive},modifier=Modifier.fillMaxWidth()){Text("${c.name} · ${if(c.isActive)"active" else "inactive"} · ${c.sortOrder}")}}
 }
}
