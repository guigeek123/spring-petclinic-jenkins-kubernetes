import json
import requests
import requests.exceptions
import requests.packages.urllib3

from . import __version__ as version

class DDTrackAPI(object):
    """An API wrapper for Dependency Track."""

    def __init__(self, host, api_key, api_version='v1', verify_ssl=True, timeout=60, proxies=None,  user_agent=None, debug=False):
        """Initialize a Dependency Track API instance.

        :param host: The URL for the DefectDojo server. (e.g., http://localhost:8000/DefectDojo/)
        :param api_key: The API key generated on the DefectDojo API key page.
        :param api_version: API version to call, the default is v1.
        :param verify_ssl: Specify if API requests will verify the host's SSL certificate, defaults to true.
        :param timeout: HTTP timeout in seconds, default is 30.
        :param proxis: Proxy for API requests.
        :param user_agent: HTTP user agent string, default is "DDTrack_api/[version]".
        :param debug: Prints requests and responses, useful for debugging.

        """

        self.host = host + '/api/' + api_version + '/'
        self.api_key = api_key
        self.api_version = api_version
        self.verify_ssl = verify_ssl
        self.proxies = proxies
        self.timeout = timeout

        if not user_agent:
            self.user_agent = 'DDTrack_api/' + version
        else:
            self.user_agent = user_agent

        self.debug = debug  # Prints request and response information.

        if not self.verify_ssl:
            requests.packages.urllib3.disable_warnings()  # Disabling SSL warning messages if verification is disabled.


    ###### API Functions ######
    def create_project(self, project_name, version):
        """Creates a new project.

        :param project_name: Name of the project

        """
        data = {}
        data['name']=project_name
        data['version']=version

        return self._request('PUT', 'project', data=data)


    def get_project_list(self):
        """Returns the list of projects in Dependency Track server.

        :param project_name: Name of the project

        """
        return self._request('GET', 'project/')


    def upload_scan(self, jsonPayload):
        """Returns the list of projects in Dependency Track server.

        :param jsonPayload: json file containing projectId and encored report

        """

        self._request('PUT', 'scan', data=jsonPayload)






    def _request(self, method, url, params=None, data=None, files=None):
        """Common handler for all HTTP requests."""
        if not params:
            params = {}

        if data:
            data = json.dumps(data)

        headers = {
            'User-Agent': self.user_agent,
            'X-Api-Key' : self.api_key
        }

        if not files:
            headers['Accept'] = 'application/json'
            headers['Content-Type'] = 'application/json'

        if self.proxies:
            proxies=self.proxies
        else:
            proxies = {}

        try:
            if self.debug:
                print(method + ' ' + url)
                print(params)

            response = requests.request(method=method, url=self.host + url, params=params, data=data, files=files, headers=headers,
                                        timeout=self.timeout, verify=self.verify_ssl, proxies=proxies)

            if self.debug:
                print(response.status_code)
                print(response.text)

            try:
                if response.status_code == 404: #Created new object
                    return DDTrackResponse(message="Object Not Found", data=data, success=True)
                elif response.status_code == 403:
                    return DDTrackResponse(message="Unauthorized Error (403) : check access rights on Dependency Track (e.g. : 'PORTFOLIO_MANAGEMENT' ??)", success=False, data=response.text)
                elif response.status_code == 500:
                    return DDTrackResponse(message="An error 500 occured in the API.", success=False, data=response.text)
                else:
                    data = response.json()
                    return DDTrackResponse(message="Success", data=data, success=True, response_code=response.status_code)
            except ValueError:
                return DDTrackResponse(message='JSON response could not be decoded.', success=False, data=response.text)
        except requests.exceptions.SSLError:
            return DDTrackResponse(message='An SSL error occurred.', success=False)
        except requests.exceptions.ConnectionError:
            return DDTrackResponse(message='A connection error occurred.', success=False)
        except requests.exceptions.Timeout:
            return DDTrackResponse(message='The request timed out after ' + str(self.timeout) + ' seconds.',
                                      success=False)
        except requests.exceptions.RequestException:
            return DDTrackResponse(message='There was an error while handling the request.', success=False)


class DDTrackResponse(object):
    """
    Container for all DefectDojo API responses, even errors.

    """

    def __init__(self, message, success, data=None, response_code=-1):
        self.message = message
        self.data = data
        self.success = success
        self.response_code = response_code

    def __str__(self):
        if self.data:
            return str(self.data)
        else:
            return self.message

    def id(self):
        if self.response_code == 400: #Bad Request
            raise ValueError('Object not created:' + json.dumps(self.data, sort_keys=True, indent=4, separators=(',', ': ')))
        return int(self.data)

    def count(self):
        return self.data["meta"]["total_count"]

    def data_json(self, pretty=False):
        """Returns the data as a valid JSON string."""
        if pretty:
            return json.dumps(self.data, sort_keys=True, indent=4, separators=(',', ': '))
        else:
            return json.dumps(self.data)
