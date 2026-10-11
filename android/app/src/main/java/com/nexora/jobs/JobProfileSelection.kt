@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.nexora.jobs

import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** Selection is hoisted into MVVM. Collapsing this component never resets IDs. */
@Composable
fun JobProfileSelection(
 categories: List<JobCategory>, selectedIds: Set<String>, onSelectionChange: (Set<String>)->Unit,
 modifier: Modifier=Modifier, title: String="Job Profile", hindi: Boolean=false,
 loading: Boolean=false,error: String?=null,onRetry: ()->Unit={},required: Boolean=false,showValidation: Boolean=false,
 allowSelectAll: Boolean=false,historicalIds: Set<String> = selectedIds
) {
 val ctx=LocalFormContext.current;val bring=remember{BringIntoViewRequester()}
 LaunchedEffect(ctx.attempt){if(ctx.errors.keys.firstOrNull()=="Job Profile")bring.bringIntoView()}
 var expanded by rememberSaveable { mutableStateOf(true) }
 var search by rememberSaveable { mutableStateOf("") }
 val visible=categories.filter { (it.isActive||(selectedIds.contains(it.id)&&historicalIds.contains(it.id)))&&(it.name.contains(search,true)||it.nameHi.contains(search,true)) }
 val historical=categories.filter{!it.isActive&&selectedIds.contains(it.id)&&historicalIds.contains(it.id)}.map{it.id}.toSet()
 OutlinedCard(modifier.fillMaxWidth().bringIntoViewRequester(bring),shape=RoundedCornerShape(16.dp)) {
  TextButton(onClick={expanded=!expanded},modifier=Modifier.fillMaxWidth().heightIn(min=56.dp)) {
   Column(Modifier.weight(1f),horizontalAlignment=Alignment.Start){
    Text(title,style=MaterialTheme.typography.titleMedium,modifier=Modifier.semantics{heading()})
    Text(if(hindi)"${selectedIds.size} प्रोफ़ाइल चयनित" else "${selectedIds.size} profiles selected",style=MaterialTheme.typography.bodySmall)
   }
   Text(if(expanded)"⌃" else "⌄",style=MaterialTheme.typography.titleLarge)
  }
  if(expanded){
   Row(Modifier.padding(horizontal=12.dp),verticalAlignment=Alignment.CenterVertically){
    OutlinedTextField(search,{search=it},label={Text(if(hindi)"प्रोफ़ाइल खोजें" else "Search profiles")},modifier=Modifier.weight(1f),singleLine=true)
    TextButton(onClick={onSelectionChange(emptySet())}){Text(if(hindi)"चयन हटाएँ" else "Clear Selection")}
   }
   if(allowSelectAll)TextButton(onClick={onSelectionChange(categories.filter{it.isActive}.map{it.id}.toSet()+historical)},modifier=Modifier.padding(horizontal=12.dp)){Text(if(hindi)"सभी चुनें" else "Select all")}
   when {
    loading -> CircularProgressIndicator(Modifier.padding(20.dp))
    error!=null -> Column(Modifier.padding(16.dp)){Text(error,color=MaterialTheme.colorScheme.error);TextButton(onRetry){Text(if(hindi)"फिर प्रयास करें" else "Retry")}}
    categories.isEmpty() -> Text(if(hindi)"अभी कोई श्रेणी उपलब्ध नहीं है। बाद में प्रयास करें।" else "No profiles available. Please try again later.",Modifier.padding(16.dp))
    visible.isEmpty() -> Text(if(hindi)"कोई प्रोफ़ाइल नहीं मिला।" else "No matching profiles.",Modifier.padding(16.dp))
    else -> LazyColumn(Modifier.fillMaxWidth().heightIn(max=280.dp).padding(8.dp)) {
     items(visible,key={it.id}) { category ->
      val checked=category.id in selectedIds
      Row(Modifier.fillMaxWidth().background(if(checked)MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,RoundedCornerShape(8.dp))
       .toggleable(value=checked,enabled=category.isActive,role=Role.Checkbox,onValueChange={value->onSelectionChange(if(value)selectedIds+category.id else selectedIds-category.id)})
       .heightIn(min=52.dp).padding(horizontal=8.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically) {
        Checkbox(checked,onCheckedChange=null,enabled=category.isActive)
        Spacer(Modifier.width(8.dp))
        Text(category.label(hindi)+(if(!category.isActive)if(hindi)" (निष्क्रिय · सहेजा गया)" else " (inactive · saved)" else ""),modifier=Modifier.weight(1f),color=if(checked)MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
      }
     }
    }
   }
  }
  if(required&&showValidation&&selectedIds.isEmpty())Text(if(hindi)"कम से कम एक जॉब प्रोफ़ाइल चुनें।" else "Select at least one job profile.",color=MaterialTheme.colorScheme.error,modifier=Modifier.padding(16.dp))
 }
}
