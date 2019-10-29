jQuery( document ).ready(function () {
    RT.NewEditor = class LifecycleEditorNew extends LifecycleModel {
        constructor(container, name, config) {
            super("LifecycleModel");

            var self      = this;
            self.width    = 809;
            self.height   = 500;
            self.svg      = d3.select(container).select('svg')
                .attr('width', self.width )
                .attr('height', self.height );
            self.config   = config;
            self.links    = [];
            self.nodes    = [];

            self.nodesFromConfig(config);
            self.nodes.forEach(function(node) {
                self.linksForNode(node.name).forEach(function(link) {
                    self.links.push({id: self.links.length, source: node, target: {name: link}});
                });
            });

            self.simulation = d3.forceSimulation()
                .force("link", d3.forceLink().distance(10).strength(0.5))
                .force("charge", d3.forceManyBody())
                .force("center", d3.forceCenter(self.width / 2, self.height / 2));

            self.link = self.svg.selectAll(".link")
                .data(self.links.filter(function(d) { return d.id; }))
                .enter().append("path")
                .attr("class", "link");

            self.node = self.svg.selectAll("g")
                .data(self.nodes.filter(function(d) { return d.name; }))
                .enter().append("circle")
                    .attr("class", "node")
                    .attr("r", 15)
                    .attr("fill", '#ccc' )
                    .call(d3.drag()
                        .on("start", dragstarted)
                        .on("drag", dragged)
                        .on("end", dragended))

        // .append("text")
                //     .attr("dx", 300)
                //     .attr("fill", "#fff")
                //     .text(function (d) { return 'test'; })
                //     .each(function () { self.truncateLabel(this); });
            self.node.append("title")
                .text(function(d) { return d.name; });

            self.simulation
                .nodes(self.nodes)
                .on("tick", tick, '');

            self.simulation.force("link")
                .links(self.links);

            // FIXME We shouldn't need to do this
            var simulation = self.simulation;
            function tick() {
                self.node.attr('cx', function(d){ return d.x; })
                    .attr('cy', function(d){ return d.y; })
    
                self.link.attr('x1', function(d) { return d.source.x; })
                    .attr('y1', function(d) { return d.source.y; })
                    .attr('x2', function(d) { return d.target.y; })
                    .attr('x2', function(d) { return d.target.y; })
            }

            function dragstarted(d) {
                if (!d3.event.active) self.simulation.alphaTarget(0.3).restart();
                d.fx = d.x, d.fy = d.y;
            }

            function dragged(d) {
                d.fx = d3.event.x, d.fy = d3.event.y;
            }
    
            function dragended(d) {
                if (!d3.event.active) simulation.alphaTarget(0);
                d.fx = null, d.fy = null;
            }
        }

        setUp() {
            var self = this;

            // De-focus when clicking our SVG background
            self.svg.on('click', function(){ self.defocus() } );

            self.svg.on('dblclick', function () {
                d3.event.preventDefault();

                // self.addNewStatus();
                self.refresh();
            });
        }

        refresh() {
            renderTransitions();
            renderNodes();
        }

        renderTransitions() {
            var self  = this;
            self.link = self.svg.selectAll(".link")
                .data(self.links)
                .enter().append("path")
                .attr("class", "link");
        }

        renderNodes() {

        }

        truncateLabel(element) {
            var node = d3.select(element), textLength = node.node().getComputedTextLength(), text = node.text();
            while (textLength > this.statusCircleRadius * 1.8 && text.length > 0) {
                text = text.slice(0, -1);
                node.text(text + '…');
                textLength = node.node().getComputedTextLength();
            }
        }
    }
});