extends Node

class_name ServerConfigClass

const HEARTBEAT_INTERVAL = 1.0
const HEARTBEAT_TIMEOUT = 3.0
const SPAWN_RADIUS = 64
const MAX_INSTANCES_PER_STAGE = 10
const INSTANCE_PLAYER_LIMIT = 3

const DEFAULT_PORT = 9000
const DEFAULT_SERVER_IP = "127.0.0.1"

# Logging levels
enum LogLevel { ERROR, WARN, INFO, DEBUG }
var current_log_level = LogLevel.DEBUG
