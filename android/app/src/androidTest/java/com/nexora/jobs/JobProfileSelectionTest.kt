package com.nexora.jobs

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test

class JobProfileSelectionTest {
 @get:Rule val compose=createComposeRule()
 private val categories=listOf(JobCategory("a","Beautician","ब्यूटीशियन",true,0),JobCategory("b","Makeup Artist","मेकअप आर्टिस्ट",true,1),JobCategory("c","Inactive","निष्क्रिय",false,2))
 @Test fun multiSelectionSurvivesCollapse(){
  compose.setContent { MaterialTheme { var ids by remember{mutableStateOf(emptySet<String>())};JobProfileSelection(categories,ids,{ids=it}) } }
  compose.onNodeWithText("Beautician").performClick()
  compose.onNodeWithText("Makeup Artist").performClick()
  compose.onNodeWithText("2 profiles selected").assertExists()
  compose.onNodeWithText("Job Profile").performClick()
  compose.onNodeWithText("Beautician").assertDoesNotExist()
  compose.onNodeWithText("Job Profile").performClick()
  compose.onNodeWithText("Beautician").assertIsOn()
  compose.onNodeWithText("Makeup Artist").assertIsOn()
 }
 @Test fun inactiveCategoryIsNotSelectable(){
  compose.setContent { MaterialTheme { JobProfileSelection(categories,emptySet(),{}) } }
  compose.onNodeWithText("Inactive").assertDoesNotExist()
 }
 @Test fun historicalInactiveSelectionCanBeIntentionallyCleared(){
  compose.setContent { MaterialTheme { var ids by remember{mutableStateOf(setOf("a","c"))};JobProfileSelection(categories,ids,{ids=it}) } }
  compose.onNodeWithText("Inactive (inactive · saved)").assertIsOn().assertIsNotEnabled()
  compose.onNodeWithText("Clear Selection").performClick()
  compose.onNodeWithText("0 profiles selected").assertExists()
  compose.onNodeWithText("Inactive (inactive · saved)").assertDoesNotExist()
 }
}
