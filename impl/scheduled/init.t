-- impl/scheduled/init.t
-- Installs Scheduled-phase method implementations.

require("impl/scheduled/binding")
require("impl/scheduled/tempo_map")
require("impl/scheduled/step")
require("impl/scheduled/graph_plan")
require("impl/scheduled/node_job")
require("impl/scheduled/clip_job")
require("impl/scheduled/mod_job")
require("impl/scheduled/send_job")
require("impl/scheduled/mix_job")
require("impl/scheduled/output_job")
require("impl/scheduled/project")

return true
