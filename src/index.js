'use strict';

var debug = require('debug')('release-scripting');

module.exports = function () {

  return {
    healthcheck: healthcheck
  };

  function healthcheck(callback) {
    debug('Healthcheck: OK');
    callback(null, 'OK');
  }
};
