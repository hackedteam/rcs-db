var dbs = db.getMongo().getDBNames()
for(var i in dbs){
    db = db.getMongo().getDB( dbs[i] );
    print( "adding auth to " + db.getName() );
    db.addUser("root", "MongoRCS daVinci")
}