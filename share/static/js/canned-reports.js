//MARK: Helper

function getReportResults(parameters, kind, completion) {
    var url = "/Helpers/CannedReports?cmd=results";
    if (kind) {
        url += "&kind=" + kind;
    }
    for (var key in parameters) {
        url += "&" + key + "=" + parameters[key];
    }
    submit(url, null, null, function(code, message, content) {
           completion(code == 200, content);
    })
}

function submit(path, pairs, data, completion) {
//    jQuery.post(path, pairs, function(object) {
//        completion(object["code"], object["message"], object["content"])
//    },'json');

    jQuery.ajax({url: path,
                success: function(object) {
                    completion(object["code"], object["message"], object["content"])
                },
                dataType: 'json',
                async: true
    });
}


//MARK: Tools

function getQueryParams() {
    var qs = document.location.search.split('+').join(' ');

    var params = {},
    tokens,
    re = /[?&]?([^=]+)=([^&]*)/g;

    while (tokens = re.exec(qs)) {
        params[decodeURIComponent(tokens[1])] = decodeURIComponent(tokens[2]);
    }

    return params;
}


//MARK: State

var _parameters = getQueryParams();
var _paramsTimer = {};
function setParameter(key, value) {
    if (_parameters[key] !== value) {
        _parameters[key] = value;
        window.clearTimeout(_paramsTimer);
        _paramsTimer = window.setTimeout(function() {paramsChanged()}, 10);
    }
}

function paramsChanged() {
    updateMenu();
    setGraphNeedsUpdate();
}

jQuery(document).ready(function() {
    setParameter("name", "Resolved");
})


//MARK: Menu

function updateMenu() {
    //Report name menu item
    var menu = jQuery("#name.reports-menu-item")
    var label = menu.find("div").find("span")
    label.text(_parameters["name"])
}

jQuery(document).ready(function() {
    jQuery(".reports-menu-item-btn").on('click', '*', function() {
        jQuery('.reports-menu-item-content').hide();
        var menu = jQuery(this).parents(".reports-menu-item");
        menu.find(".reports-menu-item-content").toggle();
    })
})

window.onclick = function(event) {
    //Close open menus
    if (!jQuery(event.target).parent().hasClass('reports-menu-item-btn')) {
        jQuery('.reports-menu-item-content').hide();
    }
}


//MARK: Graph
var _graphUpdateTimer = {}
function setGraphNeedsUpdate(key, value) {
    window.clearTimeout(_graphUpdateTimer)
    _graphUpdateTimer = window.setTimeout(function() {updateGraph()}, 10)
}

var graphIsUpdating = false
function updateGraph() {
    if (!graphIsUpdating) {
        graphIsUpdating = true
        graphBeganUpdating()
        window.setTimeout(function() {
            getReportResults(_parameters, null, function (success, content) {
                if (success) {
                    updateGraphData(content, function() {
                        graphIsUpdating = false
                        graphFinishedUpdating()
                    })
                }else{
                    alert("Sorry! Graph update failed.");
                    graphIsUpdating = false
                    graphFinishedUpdating()
                }
            })
        }, 10);
    }
}

function graphBeganUpdating() {
    jQuery('.reports-menu').hide();
    jQuery('.reports-menu-loading').show();
}

function graphFinishedUpdating() {
    jQuery('.reports-menu-loading').hide();
    jQuery('.reports-menu').show();
}


