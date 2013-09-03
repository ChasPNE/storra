# This spec tests the node-dirty backend by mocking/spying node-dirty and any
# other dependency.
describe "The node-dirty backend (with mocked dependencies)", ->

  sandbox = null
  fs = null
  dirty = null
  backend = null
  collection = null
  writeDocument = null
  writeEnd = null
  writeResponse = null

  beforeEach ->
    sandbox = require 'sandboxed-module'
    collection = jasmine.createSpyObj('collection', [
      'forEach'
      'get'
      'set'
      'rm'
      'once'
    ])
    dirty = jasmine.createSpyObj('dirty', [
      'Dirty'
    ])
    dirty.Dirty.andReturn(collection)

    fs = jasmine.createSpyObj('fs', [
      'exists'
      'unlink'
    ])
    NodeDirtyConnector =
      sandbox.require '../../lib/backends/node_dirty_backend',
      requires:
        'dirty': dirty
        'fs': fs
    backend = new NodeDirtyConnector()
    backend.init()

    writeDocument = jasmine.createSpy('writeDocument')
    writeEnd = jasmine.createSpy('writeEnd')
    writeResponse = jasmine.createSpy('writeResponse')

  it "lists a collection", ->
    backend.list('collection', writeDocument, writeEnd)
    whenCallback(collection.once, 1).thenCallIt(backend)
    whenCallback(collection.forEach, 0).thenCallIt(backend, 'key', {a: "b"})
    expect(writeDocument).toHaveBeenCalledWith({a: "b", _id: 'key'})
    expect(writeEnd).toHaveBeenCalledWith(null)

  # Duplication: Same test (and same implementation) as for nStore backend
  it "removes an existing collection", ->
    backend.removeCollection('collection', writeResponse)
    whenCallback(fs.exists, 1).thenCallIt(backend, true)
    expect(fs.unlink).toHaveBeenCalled()
    whenCallback(fs.unlink, 1).thenCallIt(backend, 'error')
    expect(writeResponse).toHaveBeenCalledWith('error')

  # Duplication: Same test (and same implementation) as for nStore backend
  it "does not falter when trying to remove a non-existing collection", ->
    backend.removeCollection('collection', writeResponse)
    whenCallback(fs.exists, 1).thenCallIt(backend, false)
    expect(fs.unlink).not.toHaveBeenCalled()
    expect(writeResponse).toHaveBeenCalledWith(null)

  it "reads a document", ->
    collection.get.andReturn({a: "b"})
    backend.read('collection', 'key', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.get).toHaveBeenCalledWith('key')
    expect(writeResponse).toHaveBeenCalledWith(undefined, {a: "b", _id: 'key'},
        'key')

  it "says 404 when reading an non-existing document", ->
    collection.get.andReturn(null)
    backend.read('collection', 'key', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.get).toHaveBeenCalledWith('key')
    expect(writeResponse).toHaveBeenCalledWith(jasmine.any(Object), null, 'key')
    expect(writeResponse.mostRecentCall.args[0].httpStatus).toEqual(404)

  it "creates a document", ->
    backend.create('collection', 'document', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.set).toHaveBeenCalledWith(jasmine.any(String), 'document')
    expect(writeResponse).toHaveBeenCalledWith(undefined, jasmine.any(String))

  it "updates a document", ->
    collection.get.andReturn({a: "b"})
    backend.update('collection', 'key', 'document', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.set).toHaveBeenCalledWith('key', 'document')
    expect(writeResponse).toHaveBeenCalledWith(undefined)

  it "throws 404 error when updating a non-existing document", ->
    collection.get.andReturn(undefined)
    backend.update('collection', 'key', 'document', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.set).not.toHaveBeenCalled()
    expect(writeResponse).toHaveBeenCalled()
    expect(writeResponse.mostRecentCall.args[0].httpStatus).toEqual(404)

  it "removes a document", ->
    backend.remove('collection', 'key', writeResponse)
    whenCallback(collection.once, 1).thenCallIt(backend)
    expect(collection.rm).toHaveBeenCalledWith('key')
    expect(writeResponse).toHaveBeenCalled()


  whenCallback = (spy, callbackIndex) ->
    callback = spy.mostRecentCall.args[callbackIndex]
    ret =
      thenCallIt: (callOn, args...) ->
        callback.call(callOn, args...)
    return ret
