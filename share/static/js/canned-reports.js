//MARK: Helper

function getReportNames(completion) {
    submit("/Helpers/CannedReports?cmd=names", null, null, function(code, message, content) {
           completion(code == 200, content);
    })
}

function getReportResults(reportIndex, completion) {
    submit("/Helpers/CannedReports?cmd=results&i=" + reportIndex, null, null, function(code, message, content) {
           completion(code == 200, content);
    })
}

function getReportResultsTable(reportIndex, completion) {
    submit("/Helpers/CannedReports?cmd=results&kind=table&i=" + reportIndex, null, null, function(code, message, content) {
           completion(code == 200, content);
    })
}

function submit(path, pairs, data, completion) {
    jQuery.post(path, pairs, function(object) {
        completion(object["Code"], object["Message"], object["Content"])
    },'json');
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
    _parameters[key] = value;
    window.clearTimeout(_paramsTimer);
    _paramsTimer = window.setTimeout(function() {paramsChanged()}, 30);
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

function updateGraph() {
    alert("updateGraph called :)");
}

var _graphUpdateTimer = {}
function setGraphNeedsUpdate(key, value) {
    window.clearTimeout(_graphUpdateTimer)
    _graphUpdateTimer = window.setTimeout(function() {updateGraph()}, 2000)
}

