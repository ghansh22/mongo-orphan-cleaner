// Script assumes it is run on a mongos instance. Should fail otherwise.

// Expects the follow parameters:
// databaseName: String name of the database to clean.
// collectionName: String name of the collection to clean.
// waitMs: [Optional] Number of milliseconds to wait between calls to cleanupOrphaned

// Supply these parameters by evaluating a string in the command line e.g.
// mongo --eval 'var databaseName = "dbName"; var collectionName = "colName"; var waitMs = 40000;' deorphaner.js

// Takes a connection to Mongos and returns an array of some host in the shard.
function findShards(mongosDb) {
  var shards = mongosDb.runCommand( { listShards: 1 } ).shards;

  if (!shards.ok) {
    throw "Could not get shards from Mongos";
  }

  return shards.map((shard) => {
    return shard.host.split(",").pop();
  });
}

// Takes a host(:port) string and returns an admin DB connections
// to that host's primary replica (or itself if it is primary).
function hostToPrimaryConnection(host) {
  var hostAdmin = connect(host).getSiblingDB('admin');
  var isMasterOutput = hostAdmin.runCommand({isMaster: 1});

  if (!isMasterOutput.ok) {
    throw "Failed to fetch isMaster data";
  }

  if (isMasterOutput.ismaster) {
    print("Primary: " + host);
    return hostAdmin;
  } else {
    var primary = isMasterOutput.primary;
    print("Primary: " + primary);
    return connect(isMasterOutput.primary).getSiblingDB('admin');
  }
}

// Takes an admin connection to a replica and runs cleanupOrphaned
// on it. Uses secondary throttle and parameterized sleep (in milliseconds)
// to encourage a safe pace.
function cleanOrphans(adminDbConn) {
  var target = databaseName + "." + collectionName;

  var nextKey = { };
  var result;

  while ( nextKey != null ) {
    result = adminDbConn.runCommand( {
      cleanupOrphaned: target,
      startingFromKey: nextKey,
      secondaryThrottle: true
    } );


    printjson(result);

    if (result.ok != 1) {
       throw "Unable to clean up orphan: failure or timeout.";
     }

    nextKey = result.stoppedAtKey;

    if (nextKey != null)
      sleep(waitMs);
  }
  return;
}

function cleanShard(hostStr) {
  var primary = hostToPrimaryConnection(hostStr);
  cleanOrphans(primary);
}

// START OF MAIN

if (typeof databaseName !== "string") {
  throw "No databaseName defined";
}
if (typeof collectionName !== "string") {
  throw "No collectionName defined";
}
if (typeof waitMs === "undefined") {
  var waitMs = 60000;
}
if (typeof waitMs !== "number") {
  throw "waitMs was defined as something besides a number";
}

adminDb = db.getSiblingDB('admin');

shardHosts = findShards(adminDb);
shardHosts.forEach((hostStr) => {
  print("Going to clean for shard: " + hostStr);
  cleanShard(hostStr);
  return;
});
