# Use make -j9 run_init to run and initialize a cluster.
# Use make -j6 run_mongo thereafter to run the cluster

CONFIG_REPLSET_NAME = config_repl_set
CONF_DATA_DIR = confData/

REPLSET_NAME1 = repl_set1
REPLSET_NAME2 = repl_set2

CONFIG_PORT = 27019

PORT1 = 27021
DATA1 = data1/
PORT2 = 27022
DATA2 = data2/
PORT3 = 27023
DATA3 = data3/
PORT4 = 27024
DATA4 = data4/
S_PORT = 27025

DATABASE = deorphaner

define CONFIG_INITIATE
rs.initiate(
  {
    _id: "$(CONFIG_REPLSET_NAME)",
    configsvr: true,
    members: [
      { _id : 0, host : "127.0.0.1:$(CONFIG_PORT)" }
    ]
  }
)
endef
define RS_INITIATE1
rs.initiate(
  {
    _id : "$(REPLSET_NAME1)",
    members: [
      { _id : 0, host : "127.0.0.1:$(PORT1)" },
      { _id : 1, host : "127.0.0.1:$(PORT2)" },
    ]
  }
)
endef
define RS_INITIATE2
rs.initiate(
  {
    _id : "$(REPLSET_NAME2)",
    members: [
      { _id : 0, host : "127.0.0.1:$(PORT3)" },
      { _id : 1, host : "127.0.0.1:$(PORT4)" },
    ]
  }
)
endef

export CONFIG_INITIATE
export RS_INITIATE1
export RS_INITIATE2
echo:
	echo "$$CONFIG_INITIATE"

run_configsvr:
	mkdir -p $(CONF_DATA_DIR)
	mongod --configsvr --replSet $(CONFIG_REPLSET_NAME) --dbpath $(CONF_DATA_DIR)

# make -j6 run_mongo
run_mongo: run_configsvr run_shardsvr1 run_shardsvr2 run_shardsvr3 run_shardsvr4 run_mongos

# make -j9 run_init
run_init: run_mongo rs_init add_shards

run_shardsvr1:
	sleep 5
	mkdir -p $(DATA1)
	mongod --shardsvr --replSet $(REPLSET_NAME1) --port $(PORT1) --dbpath $(DATA1)

run_shardsvr2:
	sleep 5
	mkdir -p $(DATA2)
	mongod --shardsvr --replSet $(REPLSET_NAME1) --port $(PORT2) --dbpath $(DATA2)

run_shardsvr3:
	sleep 5
	mkdir -p $(DATA3)
	mongod --shardsvr --replSet $(REPLSET_NAME2) --port $(PORT3) --dbpath $(DATA3)

run_shardsvr4:
	sleep 5
	mkdir -p $(DATA4)
	mongod --shardsvr --replSet $(REPLSET_NAME2) --port $(PORT4) --dbpath $(DATA4)

rs_init:
	sleep 10
	mongo --port $(CONFIG_PORT) --eval "$$CONFIG_INITIATE"
	mongo --port $(PORT1) --eval "$$RS_INITIATE1"
	mongo --port $(PORT3) --eval "$$RS_INITIATE2"

run_mongos:
	sleep 5
	mongos --configdb $(CONFIG_REPLSET_NAME)/127.0.0.1:$(CONFIG_PORT) --port $(S_PORT)

add_shards:
	sleep 20
	mongo --port $(S_PORT) --eval 'sh.addShard("$(REPLSET_NAME1)/127.0.0.1:$(PORT1)")'
	mongo --port $(S_PORT) --eval 'sh.addShard("$(REPLSET_NAME2)/127.0.0.1:$(PORT3)")'
	mongo --port $(S_PORT) --eval 'sh.enableSharding("$(DATABASE)")'

clean:
	rm -rf $(CONF_DATA_DIR) $(DATA1) $(DATA2) $(DATA3) $(DATA4)
