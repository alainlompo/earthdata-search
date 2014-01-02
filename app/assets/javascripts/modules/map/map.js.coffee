ns = window.edsc.map

ns.Map = do (window,
             document,
             L,
             ProjExt = ns.L.Proj,
             ProjectionSwitcher = ns.L.ProjectionSwitcher
             LayerBuilder = ns.LayerBuilder,
             SpatialSelection = ns.SpatialSelection,
             dateUtil = window.edsc.util.date
             searchModel = window.edsc.models.searchModel) ->

  # Fix leaflet default image path
  L.Icon.Default.imagePath = L.Icon.Default.imagePath?.replace(/\/images$/, '') || '/assets/leaflet-0.7'

  # Constructs and performs basic operations on maps
  # This class wraps the details of setting up the map used by the application,
  # setting up GIBS layers, supported projections, etc.
  # Code outside of the edsc.map module should interact with this class only
  class Map
    # Creates a map attached to the given element with the given projection
    # Valid projections are:
    #   'geo' (EPSG:4326, WGS 84 / Plate Carree)
    #   'arctic' (EPSG:3413, WGS 84 / NSIDC Sea Ice Polar Stereographic North)
    #   'antarctic' (EPSG:3031, WGS 84 / Antarctic Polar Stereographic)
    constructor: (el, projection='geo') ->
      $(el).data('map', this)
      @layers = []
      map = @map = new L.Map(el, zoomControl: false, attributionControl: false)
      @_buildLayers()
      map.addControl(L.control.zoom(position: 'topright'))
      map.addControl(new ProjectionSwitcher())
      map.addControl(new SpatialSelection())
      @setProjection(projection)
      @_addDrawControls()

      @_datasetSubscription = searchModel.datasets.details.subscribe(@_showDatasetSpatial)
      $('#dataset-details').on('click', '.master-overlay-show-main a', @_hideDatasetSpatial)

    # Removes the map from the page
    destroy: ->
      @map.remove()
      @_datasetSubscription.dispose()
      $('#dataset-details').off('click', '.master-overlay-show-main a', @_hideDatasetSpatial)

    _createLayerMap: (productIds...) ->
      layerForProduct = LayerBuilder.layerForProduct
      projection = @projection
      result = {}
      for productId in productIds
        layer = layerForProduct(productId, projection)
        result[layer.name] = layer
      result

    _buildLayers: ->
      baseMaps = @_createLayerMap('MODIS_Terra_CorrectedReflectance_TrueColor', 'land_water_map')
      overlayMaps = @_createLayerMap('administrative_boundaries', 'coastlines')

      # Show the first layer
      for own k, layer of baseMaps
        @map.addLayer(layer)
        break

      @map.addControl(L.control.layers(baseMaps, overlayMaps))

    _addDrawControls: ->
      map = @map
      map.on 'draw:created', (e) ->

    # Adds the given layer to the map
    addLayer: (layer) -> @map.addLayer(layer)

    # Removes the given layer from the map
    removeLayer: (layer) -> @map.removeLayer(layer)

    projectionOptions:
      arctic:
        crs: ProjExt.epsg3413
        minZoom: 0
        maxZoom: 5
        zoom: 0
        continuousWorld: true
        noWrap: true
        worldCopyJump: false
        center: [90, 0]
      antarctic:
        crs: ProjExt.epsg3031
        minZoom: 0
        maxZoom: 5
        zoom: 0
        continuousWorld: true
        noWrap: true
        worldCopyJump: false
        center: [-90, 0]
      geo:
        crs: ProjExt.epsg4326
        minZoom: 1
        maxZoom: 7
        zoom: 2
        continuousWorld: false
        noWrap: false
        worldCopyJump: true
        center: [0, 0]

    setProjection: (name) ->
      map = @map
      return if @projection == name
      @projection = map.projection = name

      opts = @projectionOptions[name]
      L.setOptions(map, opts)
      map.fire('projectionchange', projection: name, map: map)
      map.setView(L.latLng(opts.center), opts.zoom, reset: true)

    # (For debugging) Display a layer with the given GeoJSON
    debugShowGeoJson: (json) ->
      layer = new L.geoJson(json);
      layer.setStyle
        color: "#0f0"
        weight: 1
        fill: false
        opacity: 1.0

      @addLayer(layer)

    # (For debugging) Log mouse lat / lon to the console as the mouse moves
    startMouseDebugging: ->
      @map.on 'mousemove', @_debugMouseMovement

    # (For debugging) Stop logging mouse lat / lon to the console
    stopMouseDebugging: ->
      @map.off 'mousemove', @_debugMouseMovement

    _debugMouseMovement: (e) =>
      console.log('mousemove', e.latlng.lat.toFixed(2), e.latlng.lng.toFixed(2))

    _showDatasetSpatial: (dataset) =>
      dataset = dataset.summaryData

      @_hideDatasetSpatial()

      layer = new L.FeatureGroup()

      @_showLine(layer, s)      for s in dataset.lines()    ? []
      @_showRectangle(layer, s) for s in dataset.boxes()    ? []
      @_showPoint(layer, s)     for s in dataset.points()   ? []
      @_showPolygon(layer, s)   for s in dataset.polygons() ? []

      layer.addTo(@map)
      @_datasetSpatialLayer = layer

    _showLine:      (layer, points) -> L.polyline(points, color: "#ff7800", weight: 1).addTo(layer)
    _showRectangle: (layer, points) -> L.rectangle(points, color: "#ff7800", weight: 1).addTo(layer)
    _showPoint:     (layer, points) -> L.marker(points...).addTo(layer)

    # FIXME: This works for datasets but will not work for granules
    _showPolygon:   (layer, points) -> L.polygon(points, color: "#ff7800", weight: 1).addTo(layer)


    _hideDatasetSpatial: =>
      if @_datasetSpatialLayer
        @map.removeLayer(@_datasetSpatialLayer)
        @_datasetSpatialLayer = null



  #datasetsModel
  #  map = $('#map').data('map')
  #  map.showDatasetSpatial(dataset) if map?



  $(document).ready ->
    projection = 'geo'
    map = new Map(document.getElementById('map'), projection)

    # Useful debugging snippets

    # Add outlines of US States to the map to help ensure correct projections and tile positioning
    #$.getJSON '/assets-dev/modules/map/debug-geojson.json', {}, (json) -> map.debugShowGeoJson(json)

    # Log the mouse lat / lon to the console
    #map.startMouseDebugging()

  exports = Map