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

var ws = new WebSocket("ws://127.0.0.1:8888/chatcom");

ws.onmessage = function (evt) {
	var msg = JSON.parse(evt.data);
	var date = new Date(msg.time);
	var hours = date.getHours();
	var minutes = date.getMinutes();
	var seconds = date.getSeconds();
	var formatted_time = hours + ':' + minutes + ':' + seconds;
	$("#chat-window").append("<p>["+ formatted_time + "] "+msg.nick+": "+msg.msg+"</p>");
};

$("#chat-submit-msg").click(function() {
	ws.send($("#chat-input").val());
	$("#chat-input").val("");
});

$("#chat-input").keyup(function(event) {
	if (event.keyCode == 13) {
		ws.send($("#chat-input").val());
		$("#chat-input").val("");
	}
});