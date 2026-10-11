package com.nexora.jobs
import android.graphics.BitmapFactory
import android.content.Intent
import android.net.Uri
import java.io.File
import androidx.core.content.FileProvider
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.PickVisualMediaRequest
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
@Composable private fun Field(label:String,value:String,change:(String)->Unit){GuidedField(label,value,change,label in listOf("Introduction","Previous employment","Address"))}
@Composable private fun Group(title:String,content:@Composable ColumnScope.()->Unit){OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text(title,style=MaterialTheme.typography.titleLarge);content()}}}
@Composable fun SavedCompletion(percent:Int,missing:List<String>){Text("Saved profile: $percent% complete");LinearProgressIndicator(progress={percent/100f},modifier=Modifier.fillMaxWidth());if(missing.isNotEmpty())Text("Complete: "+missing.joinToString(", "))}
@Composable fun ProfilePhoto(path:String,name:String,vm:PortalViewModel){var bytes by remember(path){mutableStateOf<ByteArray?>(null)};var error by remember(path){mutableStateOf(false)};var retry by remember{mutableIntStateOf(0)};var preview by remember{mutableStateOf(false)}
 LaunchedEffect(path,retry){if(path.isNotBlank())try{bytes=vm.photoBytes(path)}catch(_:Exception){error=true}}
 val bitmap=remember(bytes){bytes?.let{val opt=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeByteArray(it,0,it.size,opt);opt.inJustDecodeBounds=false;opt.inSampleSize=maxOf(1,maxOf(opt.outWidth,opt.outHeight)/600);BitmapFactory.decodeByteArray(it,0,it.size,opt)?.asImageBitmap()}}
 if(bitmap!=null){Image(bitmap,"Profile photo",Modifier.size(96.dp));TextButton({preview=true}){Text("Preview photo")}}else{Text("◉ "+name.take(1).uppercase().ifBlank{"N"},style=MaterialTheme.typography.headlineLarge);if(error)TextButton({error=false;retry++}){Text("Photo could not load · Retry")}}
 if(preview)AlertDialog(onDismissRequest={preview=false},text={bitmap?.let{Image(it,"Photo preview",Modifier.fillMaxWidth())}},confirmButton={TextButton({preview=false}){Text("Close")}})
}
@Composable fun ProfileEditor(s:PortalState,vm:PortalViewModel,owner:Boolean=false){val context=LocalContext.current;val scope=rememberCoroutineScope();val d=s.profileDraft;val o=s.ownerDraft
 val gallery=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()){it?.let{uri->vm.uploadFile(uri,owner)}}
 var capture by rememberSaveable{mutableStateOf<String?>(null)}
 val camera=rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()){ok->if(ok)capture?.let{vm.uploadFile(Uri.parse(it),owner)}}
 val resume=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){it?.let{uri->vm.uploadFile(uri,folder="resume")}}
 val portfolio=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){it?.let{uri->vm.uploadFile(uri,folder="portfolio")}}
 fun open(path:String){scope.launch{runCatching{context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(vm.fileUrl(path))))}.onFailure{vm.fileError(it.message?:"File could not open. Retry.")}}}
 Group("Profile photo"){ProfilePhoto(if(owner)o.photoPath else d.photoPath,if(owner)o.name else d.name,vm);Text("JPG, PNG or WebP · maximum 5 MB. Save to apply changes.");Button({gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))},enabled=!s.loading){Text("Upload / Change · Gallery")};if(context.packageManager.resolveActivity(Intent("android.media.action.IMAGE_CAPTURE"),0)!=null)OutlinedButton({val file=File.createTempFile("photo-",".jpg",File(context.cacheDir,"profile-camera").apply{mkdirs()});val uri=FileProvider.getUriForFile(context,context.packageName+".files",file);capture=uri.toString();camera.launch(uri)},enabled=!s.loading){Text("Take photo using camera")};TextButton({vm.removePhoto(owner)},enabled=!s.loading){Text("Remove photo")};s.photoProgress?.let{LinearProgressIndicator(progress={it/100f},modifier=Modifier.fillMaxWidth());Text("Uploading $it%")};s.photoError?.let{Text(it,color=MaterialTheme.colorScheme.error);TextButton({vm.retryPhoto()},enabled=!s.loading){Text("Retry upload")}}}
 if(owner){SavedCompletion(if(s.employer==null)0 else s.savedOwner.completion(),s.savedOwner.missing());Group("Personal Information"){Field("Full name",o.name,{vm.ownerProfile(o.copy(name=it))});Field("Mobile",o.mobile,{vm.ownerProfile(o.copy(mobile=it))});Field("Email",o.email,{vm.ownerProfile(o.copy(email=it))});Field("City",o.city,{vm.ownerProfile(o.copy(city=it))});Field("State",o.state,{vm.ownerProfile(o.copy(state=it))})};Group("Professional Information"){Field("Salon / business name",o.salon,{vm.ownerProfile(o.copy(salon=it))});Field("Address",o.address,{vm.ownerProfile(o.copy(address=it))});Field("Introduction",o.bio,{vm.ownerProfile(o.copy(bio=it))})}
 }else{SavedCompletion(if(s.candidate==null)0 else s.savedProfile.completion(),s.savedProfile.missing());Group("Personal Information"){Field("Full name",d.name,{vm.profile(d.copy(name=it))});Field("Mobile",d.mobile,{vm.profile(d.copy(mobile=it))});Field("Email",d.email,{vm.profile(d.copy(email=it))});Field("City",d.city,{vm.profile(d.copy(city=it))});Field("State",d.state,{vm.profile(d.copy(state=it))})};Group("Professional Information"){Field("Introduction",d.bio,{vm.profile(d.copy(bio=it))});Field("Current / previous title",d.currentTitle,{vm.profile(d.copy(currentTitle=it))});Field("Highest qualification",d.qualification,{vm.profile(d.copy(qualification=it))});Field("Languages · commas",d.languages,{vm.profile(d.copy(languages=it))})};Group("Skills and Experience"){JobProfileSelection(s.categories,d.ids,{vm.profile(d.copy(ids=it))},hindi=s.hindi,required=true,showValidation=s.fieldErrors.containsKey("Job Profile"),historicalIds=s.candidate?.jobProfileCategoryIds?:emptySet());Field("Skills · commas",d.skills,{vm.profile(d.copy(skills=it))});Field("Specializations · commas",d.services,{vm.profile(d.copy(services=it))});Field("Experience in years",d.years,{vm.profile(d.copy(years=it))});Field("Previous employment",d.employment,{vm.profile(d.copy(employment=it))})};Group("Job Preferences"){Field("Preferred locations · commas",d.preferredLocations,{vm.profile(d.copy(preferredLocations=it))});Field("Expected salary ₹",d.expectedSalary,{vm.profile(d.copy(expectedSalary=it))});Field("Availability to join",d.availability,{vm.profile(d.copy(availability=it))});Row{Checkbox(d.discoverable,{vm.profile(d.copy(discoverable=it))});Text("Let employers discover me",Modifier.weight(1f))};Row{Checkbox(d.alerts,{vm.profile(d.copy(alerts=it))});Text("Enable job alerts",Modifier.weight(1f))}}
 Group("Resume and Portfolio · optional"){OutlinedButton({resume.launch(arrayOf("application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document"))},enabled=!s.loading){Text("Upload / change resume")};if(d.resumePath.isNotBlank()){TextButton({open(d.resumePath)}){Text("View resume")};TextButton({vm.profile(d.copy(resumePath=""))}){Text("Remove resume")}};OutlinedButton({portfolio.launch(arrayOf("image/jpeg","image/png","image/webp"))},enabled=!s.loading&&d.portfolio.size<6){Text("Add portfolio (${d.portfolio.size}/6)")};d.portfolio.forEachIndexed{i,path->Row{TextButton({open(path)}){Text("View image ${i+1}")};TextButton({vm.profile(d.copy(portfolio=d.portfolio-path))}){Text("Remove")}}}}
 s.fieldErrors["Consent"]?.let{Text(it,color=MaterialTheme.colorScheme.error)}
 Row{Checkbox(d.consent,{vm.profile(d.copy(consent=it))});Text("I accept Nexora’s privacy policy and terms.",Modifier.weight(1f))};TextButton({context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://nexora-salon-job-portal.templateapp67.chatgpt.site/#privacy")))}){Text("Read policy and terms")}}
 Button({if(owner)vm.saveEmployer() else vm.saveProfile()},enabled=!s.loading,modifier=Modifier.fillMaxWidth()){Text("Save profile")};OutlinedButton({vm.cancelProfile(owner)},enabled=!s.loading,modifier=Modifier.fillMaxWidth()){Text("Cancel")}
}
