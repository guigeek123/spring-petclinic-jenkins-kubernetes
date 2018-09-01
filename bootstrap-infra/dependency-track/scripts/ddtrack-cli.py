#!/usr/bin/env python2

"""
Upload dependency track xml report to dependency track
"""

from __future__ import print_function
from ddtrack_api import ddtrack

import argparse
import base64
import time

def ddtrack_connection(host, api_key, proxy, debug=False):
    #Optionally, specify a proxy
    proxies = None
    if proxy:
        proxies = {
            'http': proxy,
            'https': proxy,
        }

    # Instantiate the Dependency Track api wrapper
    dt = ddtrack.DDTrackAPI(host, api_key, proxies=proxies, verify_ssl=False, timeout=360, debug=debug)

    return dt


def findProjectId(dt, projectName):
    """Return the id of the first found project with a given name.
    If no project is found, try to create one.
    NOTE : does not manage version for now.

    :param project_name: Name of the project to be searched

    """

    projectList=dt.get_project_list()

    for k in projectList.data:
        if k['name'] == projectName:
            return k['uuid']

    # If we get here, project name has not been found into project list
    response = dt.create_project(projectName,"1")
    if response.success == False:
        print(response.message)
        exit('ERROR : project does not exist and service account does not have privilege to create it')

    time.sleep(5)

    projectList=dt.get_project_list()

    for k in projectList.data:
        if k['name'] == projectName:
            return k['uuid']





def generateJsonPayload (projectId, reportFilePath):

    with open(reportFilePath, 'r') as myfile:
        encodedReport=base64.b64encode(myfile.read().replace('\n', ''))

    data = {}
    data['project'] = projectId
    data['scan'] = encodedReport

    return data


def upload_payload(dt, jsonPayload):
    # Upload payload json file to Dependency Track

    dt.upload_scan(jsonPayload)

    return 0



class Main:
    if __name__ == "__main__":
        parser = argparse.ArgumentParser(description='Simple Client for Dependency Check')
        parser.add_argument('-u', '--ddtrack-url', help='Dependency-Track server URL',
                            default='http://localhost:8380', dest='url')
        parser.add_argument('-k', '--api-key', help='Dependency-Track API Key',
                            default='', dest='apiKey')
        parser.add_argument('-p', '--project-name', help='Project Name in Dependency Track',
                            default='http://nexus-direct:8082', dest='projectName')
        parser.add_argument('-x', '--xml-report-path', help='Project Name in Dependency Check XML Report file path',
                            default='target/dependency-check-report.xml', dest='reportFilePath')
        parser.add_argument('-d', '--debug', help='Activate python api debug',
                            default='False', dest='debug')
        #parser.add_argument('-j', '--json-payload', help='JSON Payload file (preprocessed)',
        #                    default='', dest='jsonFilePath')


        #Parse out arguments
        args = vars(parser.parse_args())
        url = args["url"]
        apiKey = args["apiKey"]
        projectName = args["projectName"]
        reportFilePath = args["reportFilePath"]
        debug = args["debug"]
        #jsonFilePath = args["jsonFilePath"]

        dt = ddtrack_connection(url, apiKey, proxy=None, debug=debug)

        projectId = findProjectId(dt, projectName)
        payload = generateJsonPayload(projectId, reportFilePath)
        upload_payload(dt, payload)
