@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.nexora.jobs

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** A single primary category, using the same repository data as JobProfileSelection. */
@Composable fun JobTitleSelection(categories:List<JobCategory>,selectedId:String,onSelect:(String)->Unit,
 loading:Boolean=false,error:String?=null,onRetry:()->Unit={},showValidation:Boolean=false,historicalId:String="") {
 var expanded by rememberSaveable {mutableStateOf(false)}
 val ctx=LocalFormContext.current;val bring=remember{BringIntoViewRequester()}
 LaunchedEffect(ctx.attempt){if(ctx.errors.keys.firstOrNull()=="Job Title")bring.bringIntoView()}
 val current=categories.find{it.id==selectedId}
 Column(modifier=Modifier.bringIntoViewRequester(bring),verticalArrangement=Arrangement.spacedBy(8.dp)){
  Text("Job Title — Which staff member do you want to hire? · Required",style=MaterialTheme.typography.titleMedium)
  Text(if(ctx.hindi)"सैलून के लिए भूमिका चुनें, जैसे Beautician या Gents Hairdresser।" else "Select the type of professional you need for your salon. For example, choose Beautician if you want to hire a beautician, or Gents Hairdresser if you need a men's hair stylist.",style=MaterialTheme.typography.bodySmall)
  Box {
   OutlinedButton(onClick={expanded=true},enabled=!loading,modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text(current?.name?:"Select the staff role you want to hire",Modifier.weight(1f));Text("⌄")}
   DropdownMenu(expanded=expanded,onDismissRequest={expanded=false},modifier=Modifier.heightIn(max=320.dp)){
    categories.filter{it.isActive||(it.id==historicalId&&it.id==selectedId)}.forEach{category->DropdownMenuItem(text={Text(category.name+if(category.isActive)"" else " (inactive · saved)")},onClick={onSelect(category.id);expanded=false})}
   }
  }
  if(loading)LinearProgressIndicator(Modifier.fillMaxWidth())
  if(error!=null){Text(error,color=MaterialTheme.colorScheme.error);TextButton(onRetry){Text("Retry")}}
  if(!loading&&categories.none{it.isActive}){Text("No Job Titles available. Please retry.");TextButton(onRetry){Text("Retry")}}
  if(showValidation&&selectedId.isBlank())Text("Please select the job role you want to hire.",color=MaterialTheme.colorScheme.error)
 }
}
