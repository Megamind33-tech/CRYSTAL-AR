extends GutTest
## A roof isn't air (WorldLayout.room_at): rooms under the city's dome and
## Deep Furrow are pressurised; Dust Hollow's buildings are not; the open
## plaza isn't a room at all.


func test_which_rooms_have_air() -> void:
	var h := WorldLayout.HOLLOW
	var lift := Vector3(0, 0.5, 0)
	assert_eq(WorldLayout.room_at(WorldTerrain.at(h.x - 26, h.z - 16) + lift), WorldLayout.ROOM_NO_AIR,
			"a Hollow habitat: its airlock stands open")
	assert_eq(WorldLayout.room_at(WorldTerrain.at(h.x - 4, h.z - 30) + lift), WorldLayout.ROOM_NO_AIR,
			"the Hollow trading post: unsealed")
	var shop: Array = WorldLayout.shops()[0]
	assert_eq(WorldLayout.room_at((shop[1] as Vector3) + lift), WorldLayout.ROOM_AIR, "a city shop, under the dome")
	assert_eq(WorldLayout.room_at(WorldLayout.farm_origin() + Vector3(0, 1, 0)), WorldLayout.ROOM_AIR, "Deep Furrow is sealed")
	assert_eq(WorldLayout.room_at(CityLayout.ORIGIN + Vector3(0, 0.5, 10)), WorldLayout.NO_ROOM, "the plaza is outdoors")


func test_hollow_keeper_keeps_the_helmet_on() -> void:
	var post: Array = WorldLayout.shops()[6]
	assert_eq(post[0], "post")
	assert_eq(WorldLayout.shops()[5][0], "bar", "the Red Lantern in the city")
	assert_eq(WorldLayout.shops()[7][0], "saloon", "the Dust Devil in the Hollow")
	assert_false(CityNpcs._breathes(post[2]), "the Hollow trading post's keeper stays sealed")
	assert_true(CityNpcs._breathes(WorldLayout.shops()[2][2]), "the city store's keeper breathes the dome's air")
