var m = require("mithril");

var Rack = require("./views/Rack");
var Layout = require("./views/Layout");
var Login = require("./views/Login");
var Problem = require("./views/Problem");
var Device = require("./views/Device");

m.route(document.body, "/rack", {
    "/rack": {
        render: function() {
            return m(Layout,
              m(Rack.allRacks));
        }
    },
    "/rack/:id": {
        render: function(vnode) {
            return m(Layout,
              m(Rack.allRacks,
                m(Rack.rackLayout, vnode.attrs))
            );
        }
    },
    "/problem": {
        render: function(vnode) {
            return m(Layout,
              m(Problem.selectProblemDevice)
            );
        }
    },
    "/problem/:id": {
        render: function(vnode) {
            return m(Layout,
              m(Problem.selectProblemDevice,
                m(Problem.showDevice, vnode.attrs)
              )
            );
        }
    },
    "/device": {
        render: function(vnode) {
            return m(Layout,
              m(Device.allDevices)
            );
        }
    },
    "/device/:id": {
        render: function(vnode) {
            return m(Layout,
              m(Device.allDevices,
                m(Device.deviceReport, vnode.attrs)
              )
            );
        }
    },
    "/login": Login
});