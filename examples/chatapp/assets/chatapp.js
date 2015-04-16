// Turbo.lua Chat app using WebSockets.
//
// Copyright 2013 John Abrahamsen
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

function write_to_chatwindow (msg, time, cl) {
    var ps = $("#chat-window p");
    if (ps.length >= 100) {
        ps.first().remove();
    }
    var time_str = ("0" + time.getHours()).slice(-2)   + ":" +
    ("0" + time.getMinutes()).slice(-2) + ":" +
    ("0" + time.getSeconds()).slice(-2);

    var class_str = cl ? "class=\"" + cl + "\"": "";

    $("#chat-window").
        append("<p "+class_str+">["+ time_str + "] "+ msg +"</p>").
        animate({scrollTop: $("#chat-window").height()}, "fast");
}

function update_participants (t) {
    var list = $("#participant-list");
    var ul = $("<ul>");
    for (var i = 0; i < t.length; i++){
        ul.append("<li>"+t[i]+"</li>");
    }
    list.html(ul);
}

function connect_to_chatcom () {
    $(".connected").removeClass("hidden");
    $("#chat-input").click();
    var ws = new WebSocket("ws://" + document.location.host + "/chatcom");
    ws.onmessage = function(evt) {
        var msg = JSON.parse(evt.data);
        var pack = msg.package;
        var date = new Date(msg.time);

        switch (pack.type){
            case "participant-update":
                update_participants(pack.data);
                break;
            case "participant-joined":
                write_to_chatwindow("* " + pack.data + " joined the room.", date);
                break;
            case "participant-left":
                write_to_chatwindow("* " + pack.data + " has quit.", date);
                break;
            case "message":
                write_to_chatwindow(
                    "&lt"+pack.data.nick+"&gt; " + pack.data.msg,
                    date);
                break;
        }
    };

    $("#chat-submit-msg").click(function () {
        ws.send(JSON.stringify({
            "package": {
                "data": {
                    "msg": $("#chat-input").val()
                }
            }
        }));
        $("#chat-input").val("");
    });

    $("#chat-input").keyup(function (event) {
        if (event.keyCode == 13){
            $("#chat-submit-msg").trigger("click");
        }
    });
}

function do_login () {
    $('#login').modal('show');

    $("#chat-login-nick").keyup(function (event) {
        if (event.keyCode == 13){
            $("#chat-login-btn").click();
        }
    });

    $("#chat-login-btn").click(function(){
        $.ajax({
            type: "POST",
            url: "/signin",
            data: {nick: $("#chat-login-nick").val()},
            success: function(res){
                $('#login').modal('hide');
                connect_to_chatcom();
            }
        });
    });
}

function position_chat (w) {
    var h = w.height() - 160;
    $("#chat-window, #participant-list").css("height", h+"px");
}

$(document).ready(function () {
    $.ajax({
        type: "GET",
        url: "/signin",
        success: function (res) {
            connect_to_chatcom();
        },
        error: function(res){
            if (res.status === 400){
                do_login();
            }
        }});
    var w = $(window);
    w.resize(function(){
        position_chat(w);
    });
    position_chat(w);
});