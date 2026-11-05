#if defined _collisionhook_included
	#endinput
#endif
#define _collisionhook_included

// note: any code in this forwards should be very performant, the game will use many filtered traces per player per game frame

/**
 * Called when the game is performing vphysics collision checks between entities
 * return something other than Plugin_Continue to have the game use the result parameter
 * 
 * @param iEnt1					Entity 1 index.
 * @param iEnt2					Entity 2 index.
 * @param &bResult				Return value.
 * 
 * @return						Something other than Plugin_Continue 
 * 								to have the game use the result parameter
 */
forward Action CH_ShouldCollide(int iEnt1, int iEnt2, bool &bResult);

/**
 * Called when the game performs collision checks through traces (only for traces using filters)
 * return something other than Plugin_Continue to have the game use the result parameter
 * 
 * @param iEnt1					Entity 1 index. (client)
 * @param iEnt2					Entity 2 index. (entity)
 * @param &bResult				Return value.
 * 
 * @return						Something other than Plugin_Continue 
 * 								to have the game use the result parameter
 */
forward Action CH_PassFilter(int iEnt1, int iEnt2, bool &bResult);


public SharedPlugin __pl_collisionhook = 
{
	name = "collisionhook",
	file = "CollisionHook.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};