import json
import re
import sys
from behave import *
zap_results_file = '../reports/zap/zap_results.json'
clair_results_file = '../reports/clair/clair_results.json'

@given('we have valid zap json alert output')
def step_impl(context):
    with open(zap_results_file, 'r') as f:
        try:
            context.zap_alerts = json.load(f)
        except Exception as e:
            sys.stdout.write('Error: Invalid JSON in %s: %s\n' %
                             (zap_results_file, e))
            assert False

@given('we have valid clair json alert output')
def step_impl(context):
    with open(clair_results_file, 'r') as f:
        try:
            context.clair_alerts = json.load(f)
        except Exception as e:
            sys.stdout.write('Error: Invalid JSON in %s: %s\n' %
                             (clair_results_file, e))
            assert False

@given('the following clair accepted vulnerabilities are ignored')
def step_impl(context):
    fp_list = list()

    # Get list of accepted vulnerabilities declared in feature script
    for row in context.table:
        fp_list.append(row)

    # initialize matches list to empty list
    matches = list()

    if "Features" in context.clair_alerts['Layer']:
        features = context.clair_alerts['Layer']['Features']

        for node in features:
            # - For each components find vulnerabilities if any
            if "Vulnerabilities" in node:
                item = get_clair_item(node)
                fp_found = False
                for fp in fp_list:
                    if (fp[0]==item.title) :
                        fp_found = True;
                        break

                if (fp_found == False):
                    matches.append(item)
                else:
                    # Remove the vuln from the list in order not to take it into account on false positive analyse
                    features.remove(node)

    context.matches = matches

@given('the following clair false positive are ignored')
def step_impl(context):
    fp_list = list()

    # Get list of false positive declared in feature script
    for row in context.table:
        fp_list.append(row)

    # initialize matches list to empty list
    matches = list()

    if "Features" in context.clair_alerts['Layer']:
        features = context.clair_alerts['Layer']['Features']

        for node in features:
            # - For each components find vulnerabilities if any
            if "Vulnerabilities" in node:
                item = get_clair_item(node)
                fp_found = False
                for fp in fp_list:
                    if (fp[0]==item.title) :
                        fp_found = True;
                        break

                if (fp_found == False):
                    matches.append(item)

    context.matches = matches


@given('the following zap false positive are ignored')
def step_impl(context):
    fp_list = list()

    for row in context.table:
        fp_list.append(row)

    matches = list()
    for alert in context.zap_alerts:
        temp_alert= [alert['url'], alert['param'], alert['cweid'], alert['wascid']]
        fp_found = False
        for fp in fp_list:
            if (fp[0]==temp_alert[0] and fp[1]==temp_alert[1] and fp[2]==temp_alert[2] and fp[3]==temp_alert[3]) :
                fp_found = True;
                break

        if (fp_found == False):
            matches.append(alert)

    context.matches = matches


@given('the following zap accepted vulnerabilities are ignored')
def step_impl(context):
    fp_list = list()

    for row in context.table:
        fp_list.append(row)

    matches = list()
    for alert in context.zap_alerts:
        temp_alert= [alert['url'], alert['param'], alert['cweid'], alert['wascid']]
        fp_found = False
        for fp in fp_list:
            if (fp[0]==temp_alert[0] and fp[1]==temp_alert[1] and fp[2]==temp_alert[2] and fp[3]==temp_alert[3]) :
                fp_found = True;
                break

        if (fp_found == False):
            matches.append(alert)
        else:
            # Remove the vuln from the list in order not to take it into account on false positive analyse
            context.zap_alerts.remove(alert)

    context.matches = matches

@then('none of these zap risk levels should be present')
def step_impl(context):
    high_risks = list()
    risk_list = list()
    for row in context.table:
        risk_list.append(row['risk'])
    for alert in context.matches:
         if alert['risk'] in risk_list:
             #if not any(n['alert'] == alert['alert'] for n in high_risks):
                 high_risks.append(dict({'alert': alert['alert'],
                                          'risk': alert['risk'],
                                          'confidence': alert['confidence'],
                                          'url': alert['url'],
                                          'param': alert['param'],
                                          'cweId': alert['cweid'],
                                          'wascId': alert['wascid']
                                         }))
    if len(high_risks) > 0:
        sys.stderr.write("The following alerts failed:\n")
        for risk in high_risks:
            sys.stderr.write("\t%-5s: %s, (confidence : %s, |%s|%s|%s|%s|)\n" % (risk['alert'], risk['risk'], risk['confidence'], risk['url'], risk['param'], risk['cweId'], risk['wascId']))
        sys.stderr.write("\nFormated list for false positive management:\n")
        for risk in high_risks:
            sys.stderr.write("|%s|%s|%s|%s|\n" % (risk['url'], risk['param'], risk['cweId'], risk['wascId']))

        assert False
    assert True


@then('none of these clair risk levels should be present')
def step_impl(context):
    high_risks = list()
    risk_list = list()
    for row in context.table:
        risk_list.append(row['risk'])
    for alert in context.matches:
        if alert.severity in risk_list:
            #if not any(n['alert'] == alert['alert'] for n in high_risks):
            high_risks.append(dict({'alert': alert.title
                                    }))
    if len(high_risks) > 0:
        sys.stderr.write("The following alerts failed:\n")
        for risk in high_risks:
            sys.stderr.write("\t%-5s\n" % (risk['alert']))
        sys.stderr.write("\nFormated list for false positive management:\n")
        for risk in high_risks:
            sys.stderr.write("|%s|\n" % (risk['alert']))

        assert False
    assert True



def get_clair_item(item_node):
    severitys= ["Unknown","Negligible","Low", "Medium", "High", "Critical", "Defcon1"]
    vuln_data = []

    # - List vulnerabilites in a dict in order to order them later
    for v in item_node['Vulnerabilities']:
        vd = dict (
            namespace_name = v['NamespaceName'],
            cve_severity = v['Severity'],
            cve_name = v['Name'],
            cve_link = v['Link'],
        )

        for i in range(0, len(severitys)):
            if severitys[i] == vd['cve_severity']:
                vd['cve_severity_nr'] = i

        #Rename severities to be compliant with what's in defectDojo
        tempseverity = vd['cve_severity']

        if tempseverity == "Unknown":
            tempseverity = "Low"

        if tempseverity == "Negligible":
            tempseverity = "Info"

        #TODO : check what really means Defcon1 from Clair
        if tempseverity == "Defcon1":
            tempseverity = "Critical"

        vd['cve_severity'] = tempseverity

        vuln_data.append(vd)

    # Order vulns by criticity (more critical in first)
    vuln_data.sort(key=lambda vuln: vuln['cve_severity_nr'], reverse=True)

    # Set the finding criticity to the level of the most critical vuln
    severity = vuln_data[0]['cve_severity']


    finding = ClairFinding(title=item_node['Name'] + " (Version :" + item_node['Version'] + ")",
                      severity=severity)


    return finding


class ClairFinding(object):
    def __init__(self, title, severity):
        self.title = title;
        self.severity=severity;

