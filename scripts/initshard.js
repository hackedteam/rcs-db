db.adminCommand({ addShard : "localhost:27018" });
db.runCommand({ enablesharding : "rcs" });
db.printShardingStatus();
