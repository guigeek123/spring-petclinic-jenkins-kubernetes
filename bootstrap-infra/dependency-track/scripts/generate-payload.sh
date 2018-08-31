#!/bin/bash

cat > payload.json <<__HERE__
{
  "project": "3b3acb79-4578-4122-86dd-e4401c417299",
  "scan": "$(cat target/dependency-check-report.xml |base64 -w 0 -)"
}
__HERE__
