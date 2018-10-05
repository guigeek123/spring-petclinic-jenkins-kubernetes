#!/usr/bin/env python

import sys
import time
import json
import argparse
import re

from zapv2 import ZAPv2


def openZapProxy(args):
    args.zap_host = re.sub(r'^((?!http://).*)',
                           r'http://\1', args.zap_host)
    args.zap_host_ssh = re.sub(r'^((?!http?s://).*)',
                               r'https://\1', args.zap_host_ssh)

    return ZAPv2(proxies={'http': args.zap_host,
                          'https': args.zap_host_ssh})


def fetchArguments():
    parse = argparse.ArgumentParser()
    parse.add_argument('-z', '--zap-host', help='address and port of ZAP host',
                       default='127.0.0.1:8080', dest='zap_host')
    return parse.parse_args()


def main():
    args = fetchArguments()

    zap = openZapProxy(args)

    sys.stdout.write('Info: Scan completed; writing results in html and json formats.\n')
    # export of results in json format, to be analyzed by behave
    with open('zap-results.json', 'w') as f:
        json.dump(zap.core.alerts(), f)

if __name__ == '__main__':
    main()
