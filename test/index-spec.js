/*global describe,it*/
/*eslint max-nested-callbacks: 0*/

var expect = require('chai').expect;

var index = require('../src/index');

describe('index', function () {

  describe('healthcheck', function () {

    it('should', function (done) {
      index().healthcheck(function (err, res) {
        if (err) {
          return done(err);
        }
        expect(res).to.equal('OK');
        done();
      });
    });

  });

});
