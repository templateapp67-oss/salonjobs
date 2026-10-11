package com.nexora.jobs
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*

class JobTitleSelectionTest {
 @get:Rule val compose=createComposeRule()
 private val categories=listOf(JobCategory("a","Beautician","ब्यूटीशियन",true,0),JobCategory("b","Makeup Artist","मेकअप आर्टिस्ट",true,1),JobCategory("c","Historical","पुराना",false,2))
 @Test fun noAutomaticBeauticianAndRequiredValidation(){
  compose.setContent{MaterialTheme{JobTitleSelection(categories,"",{},showValidation=true)}}
  compose.onNodeWithText("Select the staff role you want to hire").assertExists()
  compose.onNodeWithText("Please select the job role you want to hire.").assertExists()
  compose.onNodeWithText("Select the staff role you want to hire").performClick()
  compose.onNodeWithText("Historical").assertDoesNotExist()
 }
 @Test fun singlePrimarySelectionAndDraftRestoration(){
  compose.setContent{MaterialTheme{var id by remember{mutableStateOf("")};JobTitleSelection(categories,id,{id=it})}}
  compose.onNodeWithText("Select the staff role you want to hire").performClick()
  compose.onNodeWithText("Makeup Artist").performClick()
  compose.onNodeWithText("Makeup Artist").assertExists()
  compose.onNodeWithText("Beautician").assertDoesNotExist()
  val draft=JobDraft(primaryCategoryId="b",ids=setOf("b"))
  assertEquals("b",JobDraft.from(draft.json()).primaryCategoryId)
  val candidate=ProfileDraft(ids=setOf("a","b"))
  assertEquals(setOf("a","b"),ProfileDraft.from(candidate.json()).ids)
 }
}
