var dbPass = "adminPa$$w0rd$2019"
var clusterName = "cluster"

try {
  print('Setting up InnoDB cluster...\n');
  shell.connect('admin@srv-mysql-01:3306', dbPass)
  var cluster = dba.createCluster(clusterName,{ipWhitelist:"192.168.100.0/24"});
  print('Adding instances to the cluster.');
  cluster.addInstance({user: "admin", host: "srv-mysql-02", password: dbPass})
  print('.');
  cluster.addInstance({user: "admin", host: "srv-mysql-03", password: dbPass})
  print('.\nInstances successfully added to the cluster.');
  print('\nInnoDB cluster deployed successfully.\n');
} catch(e) {
  print('\nThe InnoDB cluster could not be created.\n\nError: ' + e.message + '\n');
}

