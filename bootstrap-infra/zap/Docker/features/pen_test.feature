Feature: Pen test the Application
  Scenario: The application should not contain Cross Domain Scripting vulnerabilities
    Given we have valid json alert output
    When there is a cross domain source inclusion vulnerability
    Then none of these risk levels should be present
      | risk |
      | Medium |
      | High |
	  
  Scenario: The application should not contain SQL injection vulnerabilities
    Given we have valid json alert output
    When there is a SQL injection vulnerability
    Then none of these risk levels should be present
      | risk |
      | Medium |
      | High |