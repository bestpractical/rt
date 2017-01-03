//MARK: Helper

function getReportResults(parameters, kind, completion) {
    var url = "/Helpers/CannedReports?cmd=results";
    if (kind) {
        url += "&key=" + kind;
    }
    for (var key in parameters) {
        url += "&" + key + "=" + parameters[key];
    }
    submit(url, null, null, function(code, message, content) {
        completion(code == 200, content);
    })
}

function getReportOptions(parameters, completion) {
    var url = "/Helpers/CannedReports?cmd=options";
    for (var key in parameters) {
        url += "&" + key + "=" + parameters[key];
    }
    submit(url, null, null, function(code, message, content) {
        completion(code == 200, content);
    })
}

function getReportOptionsMenuItem(option, optionKey, parameters, completion) {
    var url = "/Helpers/CannedReports?cmd=optionsMenuItem";
    if (option) {
        url += "&key=" + option;
    }
    if (optionKey) {
        url += "&value=" + optionKey;
    }
    for (var key in parameters) {
        url += "&" + key + "=" + parameters[key];
    }
    submit(url, null, null, function(code, message, content) {
        completion(code == 200, content);
    })
}

function submit(path, pairs, data, completion) {
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
var _options;//set from within replaceOptionsMenuItems()
function updateMenu() {
    //Report name menu item
    var menu = jQuery("#name.reports-menu-item")
    var label = menu.find("div").find("span")
    if (_parameters["name"] !== label.text()) {
        label.text(_parameters["name"])
        replaceOptionsMenuItems()
    }else{
        var optionElements = jQuery(".reports-menu-options").children()
        for (e in optionElements) {
            var element = optionElements[e];
            for (i in _options) {
                var option = _options[i]
                if (option.Option === element.id) {
                    var label = jQuery(element).find("div").find("span")
                    for (v in option.Values) {
                        var value = option.Values[v]
                        if (value.Key === _parameters[option.Option]) {
                            label.text(value.Name)
                            break;
                        }
                    }
                    break;
                }
            }
        }
    }
}

function replaceOptionsMenuItems() {
    jQuery(".reports-menu-options").children().slideUp(300, function() { jQuery(this).remove() })
    getReportOptions(_parameters, function (success, content) {
        _options = content;
        for (i in content) {
            var option = content[i].Option
            if (option) {
                getReportOptionsMenuItem(option, _parameters[option], _parameters, function (success, content) {
                    jQuery(".reports-menu-options").append(content)
                    updateMenuActions()
                })
            }
        }
    })
}

jQuery(document).ready(function() {
    updateMenuActions()
})

function updateMenuActions() {
    jQuery(".reports-menu-item-btn").on('click', '*', function() {
        jQuery('.reports-menu-item-content').hide();
        var menu = jQuery(this).parents(".reports-menu-item");
        menu.find(".reports-menu-item-content").toggle();
    })
}

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


