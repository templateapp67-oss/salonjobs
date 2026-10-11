package com.nexora.jobs
import org.junit.Test
import org.junit.Assert.*
class JobFormValidationTest {
 private fun valid()=JobDraft(primaryCategoryId="id",city="Jaipur",state="Rajasthan",min="12000",max="20000",description="Hair cutting and styling",vacancies="2")
 @Test fun titleRequired(){assertEquals("Please select the job role you want to hire.",jobErrors(valid().copy(primaryCategoryId=""))["Job Title"])}
 @Test fun salaryAndVacanciesInline(){val d=valid().copy(min="20000",max="12000",vacancies="0");val errors=jobErrors(d);assertTrue(errors.containsKey("Monthly salary to (₹)"));assertTrue(errors.containsKey("Number of vacancies"));assertEquals("Hair cutting and styling",d.description)}
 @Test fun salaryRejectsNegativeFractionalAndOverflow(){listOf("-1","12.5","2147483648","bad","").forEach{assertTrue(jobErrors(valid().copy(min=it)).containsKey("Monthly salary from (₹)"))}}
 @Test fun draftIdentityPreserved(){val d=valid();assertTrue(jobErrors(d).isEmpty());assertEquals(d.submissionId,d.copy(description="Updated").submissionId);assertNotEquals(d.submissionId,valid().submissionId)}
 @Test fun profileEmailOptionalAndAuthRequired(){assertFalse(fieldRequired("profile","Email"));assertFalse(fieldRequired("employer","Email"));assertTrue(fieldRequired("auth","Email"))}
}
