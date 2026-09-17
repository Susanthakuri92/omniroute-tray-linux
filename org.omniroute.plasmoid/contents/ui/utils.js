.pragma library

function resetMinutes(isoStr) {
    if (!isoStr) return null;
    try {
        var clean = isoStr.replace("Z", "+00:00");
        var target = new Date(clean).getTime();
        var now = Date.now();
        var diff = target - now;
        if (isNaN(target) || diff <= 0) return 0;
        return Math.floor(diff / 60000);
    } catch (e) {
        return null;
    }
}

function formatResetShort(isoStr) {
    var mins = resetMinutes(isoStr);
    if (mins === null) return "";
    if (mins <= 0) return "resets soon";
    var d = Math.floor(mins / 1440);
    var h = Math.floor((mins % 1440) / 60);
    var m = mins % 60;
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

function deriveShortTag(key, resetAt) {
    var k = (key || "").toLowerCase();
    if (k.indexOf("(") !== -1 && k.indexOf(")") !== -1) {
        var inner = k.split("(")[1].split(")")[0].trim();
        if (inner.length > 0) return inner;
    }
    if (k.indexOf("monthly") !== -1 || k.indexOf("month") !== -1) return "mo";
    if (k.indexOf("weekly") !== -1 || k.indexOf("week") !== -1) return "wk";
    if (k.indexOf("session") !== -1 || k.indexOf("sess") !== -1) return "sess";
    if (k.indexOf("5h") !== -1) return "5h";
    if (k.indexOf("credit") !== -1) return "cred";
    
    // Fallback using reset minutes if available
    var mins = resetMinutes(resetAt);
    if (mins !== null && mins > 0) {
        if (mins >= 20 * 1440) return "mo";
        if (mins >= 4 * 1440) return "wk";
        if (mins >= 20 * 60) return "1d";
        if (mins >= 3 * 60) return "5h";
        return "1h";
    }
    return k.substring(0, 4);
}

function formatTokens(n) {
    var num = Number(n) || 0;
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M tokens";
    if (num >= 1000) return (num / 1000).toFixed(1) + "K tokens";
    return num + " tokens";
}

function compactTokens(n) {
    var num = Number(n) || 0;
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M";
    if (num >= 1000) return (num / 1000).toFixed(1) + "K";
    return String(num);
}

function formatCost(usd) {
    var num = Number(usd) || 0;
    return "$" + num.toFixed(2);
}

function statusColor(leftPct) {
    if (leftPct > 40) return "#22c55e"; // green
    if (leftPct > 15) return "#f59e0b"; // amber
    return "#ff2b4d"; // red
}
