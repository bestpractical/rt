
class LifecycleModel {
    nodesFromConfig(config) {
        var self      = this;
        self.nodes    = [];

        jQuery.each(['initial', 'active', 'inactive'], function (i, type) {
            config[type].forEach(element => {
                self.nodes = self.nodes.concat({name: element});
            });
        });
    }

    linksForNode (node, config) {
        var self   = this;
        var config = config || self.config;

        for (let [fromNode, toList] of Object.entries(config.transitions)) {
            if ( fromNode == node ) {
                return toList;
            }
        }
        return [];
    }
}
