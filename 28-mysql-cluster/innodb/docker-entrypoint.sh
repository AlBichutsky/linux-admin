#!/bin/bash

mysqlsh --user=root --password=mysql --host=node1 --port=3301 --interactive --file=/scripts/setupCluster.js
