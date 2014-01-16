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

function write_to_chatwindow (msg, t)  {
    var hours = t.getHours();
    var minutes = t.getMinutes();
    var seconds = t.getSeconds();
    var formatted_time = hours + ':' + minutes + ':' + seconds;
    $("#chat-window").
        append("<p>["+ formatted_time + "] "+ msg +"</p>");

}

function connect_to_chatcom () {
    var ws = new WebSocket("ws://127.0.0.1:8888/chatcom");
    ws.onmessage = function(evt) {
        var msg = JSON.parse(evt.data);
        var pack = msg.package;
        var date = new Date(msg.time);

        switch (pack.type){
            case "participant-update":
                console.log("Partc update.");
                break;
            case "participant-joined":
                write_to_chatwindow(pack.data + " joined the room.", date);
                break;
            case "participant-left":
                write_to_chatwindow(pack.data + " left the room.", date);
                break;
            case "message":
                write_to_chatwindow(
                    "["+pack.data.nick+"] " + pack.data.msg,
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
});