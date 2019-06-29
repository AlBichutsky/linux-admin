 #!/bin/bash
   
# создадим js-скрипт с командами для сборки кластера и запусим его в mysqlsh в контейнере

cat > /tmp/setupCluster.js <<EOF
var dbPass = "mysql"
var clusterName = "TestCluster"
try {
  shell.connect('root@node1:3306', dbPass)
  var cluster = dba.createCluster(clusterName);
  cluster.addInstance({user: "root", host: "node2", password: dbPass});
  cluster.addInstance({user: "root", host: "node3", password: dbPass});
} catch(e) {
  print('\nThe InnoDB cluster could not be created.\n\nError: ' + e.message + '\n');
}
EOF

until (
    mysqlsh --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --host=${MYSQL_HOST} --port=${MYSQL_PORT} --interactive --file=/tmp/setupCluster.js
)
do
    sleep 5
done
