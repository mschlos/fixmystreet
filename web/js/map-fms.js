fixmystreet.maps.tile_base = '//{S}tilma.mysociety.org/oml';

OpenLayers.Layer.BingUK = OpenLayers.Class(OpenLayers.Layer.Bing, {
    uk_bounds: [
        new OpenLayers.Bounds(-6.6, 49.8, 1.102680, 51),
        new OpenLayers.Bounds(-5.4, 51, 2.28, 54.94),
        new OpenLayers.Bounds(-5.85, 54.94, -1.15, 55.33),
        new OpenLayers.Bounds(-9.35, 55.33, -0.7, 60.98)
    ],

    in_uk: function(c) {
        c = c.clone();
        c.transform(
            fixmystreet.map.getProjectionObject(),
            new OpenLayers.Projection("EPSG:4326")
        );
        if ( this.uk_bounds[0].contains(c.lon, c.lat) || this.uk_bounds[1].contains(c.lon, c.lat) || this.uk_bounds[2].contains(c.lon, c.lat) || this.uk_bounds[3].contains(c.lon, c.lat) ) {
            return true;
        }
        return false;
    },

    setMap: function() {
        OpenLayers.Layer.Bing.prototype.setMap.apply(this, arguments);
        this.map.events.register("moveend", this, this.updateAttribution);
    },

    updateAttribution: function() {
        var z = this.map.getZoom() + this.zoomOffset;
        var copyrights;
        var logo = '';
        var c = this.map.getCenter();
        var in_uk = c ? this.in_uk(c) : true;
        var year = (new Date()).getFullYear();
        if (z >= 16 && in_uk) {
            copyrights = 'Contains Highways England and Ordnance Survey data &copy; Crown copyright and database right ' + year;
        } else {
            logo = '<a href="https://www.bing.com/maps/"><img border=0 src="//dev.virtualearth.net/Branding/logo_powered_by.png"></a>';
            if (in_uk) {
                copyrights = '&copy; ' + year + ' <a href="https://www.bing.com/maps/">Microsoft</a>, HERE, Highways England, Ordnance Survey';
            } else {
                copyrights = '&copy; ' + year + ' <a href="https://www.bing.com/maps/">Microsoft</a>, HERE, Ordnance Survey';
            }
        }
        this._updateAttribution(copyrights, logo);
    },

    tile_prefix: [ '', 'a-', 'b-', 'c-' ],

    get_urls: function(bounds, z) {
        var urls = [], i;
        var in_uk = this.in_uk(bounds.getCenterLonLat());
        if (z >= 16 && in_uk) {
            urls = [];
            for (i=0; i< this.tile_prefix.length; i++) {
                urls.push( fixmystreet.maps.tile_base.replace('{S}', this.tile_prefix[i]) + "/${z}/${x}/${y}.png" );
            }
        } else if (z > 11 && in_uk) {
            var type = 'g=8702&lbl=l1&productSet=mmOS&key=' + fixmystreet.key;
            var tile_base = "//ecn.t{S}.tiles.virtualearth.net/tiles/r${id}?" + type;
            for (i=0; i<4; i++) {
                urls.push(tile_base.replace('{S}', i));
            }
        } else {
            for (i=0; i<4; i++) {
                urls.push(this.tile_base.replace('{S}', i));
            }
        }
        return urls;
    },

    CLASS_NAME: "OpenLayers.Layer.BingUK"
});

fixmystreet.layer_options = [
  { map_type: OpenLayers.Layer.BingUK },
  { map_type: OpenLayers.Layer.BingAerial }
];
