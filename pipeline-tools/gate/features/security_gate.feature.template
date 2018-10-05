Feature: Security Gate
  Scenario: The zap report should not contain blocking vulnerabilities
    Given we have valid zap json alert output
    And the following zap accepted vulnerabilities are ignored
      |url                    |parameter          |cweId      |wascId   |

    And the following zap false positive are ignored
      |url                    |parameter          |cweId      |wascId   |

    Then none of these zap risk levels should be present
      | risk |
      | High |
      | Medium |


  Scenario: The clair report should not contain blocking vulnerabilities
    Given we have valid clair json alert output

    And the following clair accepted vulnerabilities are ignored
      |component_and_version|

    And the following clair false positive are ignored
      |component_and_version|

    Then none of these clair risk levels should be present
      | risk |
      | High |
      #| Medium |
