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


//MARK: Menu

jQuery(document).ready(function() {
    jQuery(".reports-menu-item-btn").click(function() {
        jQuery('.reports-menu-item-content').hide();
        jQuery(this).parent().find(".reports-menu-item-content").toggle();
    })
})

window.onclick = function(event) {
    if (!event.target.matches('.reports-menu-item-btn')) {
        jQuery('.reports-menu-item-content').hide();
    }
}
