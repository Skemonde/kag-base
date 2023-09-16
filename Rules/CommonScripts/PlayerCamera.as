
// set camera on local player
// this just sets the target, specific camera vars are usually set in StandardControls.as

#define CLIENT_ONLY

#include "Spectator.as"

int deathTime = 0;
Vec2f deathLock;
int helptime = 0;
bool spectatorTeam;

Vec2f pos;

void Reset(CRules@ this)
{
	SetTargetPlayer(null);
	CCamera@ camera = getCamera();
	if (camera !is null)
	{
		camera.setTarget(null);
	}

	helptime = 0;
	setCinematicEnabled(true);
	setCinematicForceDisabled(false);
	currentTarget = 0;
	switchTarget = 0;

	//initially position camera to view entire map
	ViewEntireMap();
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void onInit(CRules@ this)
{
	Reset(this);
}

void onSetPlayer(CRules@ this, CBlob@ blob, CPlayer@ player)
{
	CCamera@ camera = getCamera();
	if (camera !is null && player !is null && player is getLocalPlayer())
	{
		pos = blob.getPosition();
		camera.setPosition(pos);
		camera.setTarget(blob);
		camera.mousecamstyle = 1; //follow
	}
}

//change to spectator cam on team change
void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
	CCamera@ camera = getCamera();
	CBlob@ playerBlob = player is null ? player.getBlob() : null;

	if (camera !is null && newteam == this.getSpectatorTeamNum() && getLocalPlayer() is player)
	{
		resetHelpText();
		spectatorTeam = true;
		camera.setTarget(null);
		setCinematicEnabled(true);
		if (playerBlob !is null)
		{
			playerBlob.ClearButtons();
			playerBlob.ClearMenus();

			pos = playerBlob.getPosition();
			camera.setPosition(pos);
			deathTime = getGameTime();
		}
	}
	else if (getLocalPlayer() is player)
	{
		spectatorTeam = false;
	}
}

void resetHelpText()
{
	helptime = getGameTime();
}

//Change to spectator cam on death
void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	CCamera@ camera = getCamera();
	CBlob@ victimBlob = victim !is null ? victim.getBlob() : null;
	CBlob@ attackerBlob = attacker !is null ? attacker.getBlob() : null;

	//Player died to someone
	if (camera !is null && victim is getLocalPlayer())
	{
		resetHelpText();
		//Player killed themselves
		if (victim is attacker || attacker is null)
		{
			camera.setTarget(null);
			if (victimBlob !is null)
			{
				victimBlob.ClearButtons();
				victimBlob.ClearMenus();
				deathLock = victimBlob.getPosition();
			}
		}
		else
		{
			if (victimBlob !is null)
			{
				victimBlob.ClearButtons();
				victimBlob.ClearMenus();
			}

			if (attackerBlob !is null)
			{
				SetTargetPlayer(attackerBlob.getPlayer());
				deathLock = victimBlob.getPosition();
			}
			else
			{
				camera.setTarget(null);
			}
		}

		deathTime = getGameTime() + 1 * getTicksASecond();
		setCinematicEnabled(true);
	}
}

void SpecCamera(CRules@ this)
{
	//death effect
	CCamera@ camera = getCamera();
	if (camera !is null && getLocalPlayerBlob() is null && getLocalPlayer() !is null)
	{
		const int diffTime = deathTime - getGameTime();
		// death effect
		if (!spectatorTeam && diffTime > 0)
		{
			//lock camera
			pos = deathLock;
			camera.setPosition(deathLock);
			//zoom in for a bit
			const float zoom_target = 2.0f;
			const float zoom_speed = 5.0f;
			camera.targetDistance = Maths::Min(zoom_target, camera.targetDistance + zoom_speed * getRenderDeltaTime());
		}
		else
		{
			Spectator(this);
		}
	}
}

void onRender(CRules@ this)
{
	if (!v_capped)
	{
		SpecCamera(this);
	}

	if (targetPlayer() !is null && getLocalPlayerBlob() is null)
	{
		GUI::SetFont("menu");
		GUI::DrawText(
			getTranslatedString("Following {CHARACTERNAME} ({USERNAME})")
			.replace("{CHARACTERNAME}", targetPlayer().getCharacterName())
			.replace("{USERNAME}", targetPlayer().getUsername()),
			Vec2f(getScreenWidth() / 2 - 90, getScreenHeight() * (0.2f)),
			Vec2f(getScreenWidth() / 2 + 90, getScreenHeight() * (0.2f) + 30),
			SColor(0xffffffff), true, true
		);
	}

	if (getLocalPlayerBlob() !is null)
	{
		return;
	}

	int time = getGameTime();

	GUI::SetFont("menu");

	const Vec2f screenSize = getDriver().getScreenDimensions();
	Vec2f noticeOrigin(128, screenSize.y - 22);

	const string textEnable = getTranslatedString("Enable cinematic camera");
	const string textDisable = getTranslatedString("Disable cinematic camera");

	string text = cinematicForceDisabled ? textEnable : textDisable;

	Vec2f textEnableSize, textDisableSize;
	GUI::GetTextDimensions(textEnable, textEnableSize);
	GUI::GetTextDimensions(textDisable, textDisableSize);
	Vec2f textMaxSize(
		Maths::Max(textEnableSize.x, textDisableSize.x),
		Maths::Max(textEnableSize.y, textDisableSize.y)
	);

	Vec2f iconOrigin = noticeOrigin + Vec2f(0, -4);
	Vec2f textOrigin = noticeOrigin + Vec2f(32, 4);
	Vec2f noticeSize(
		textOrigin.x - noticeOrigin.x + textMaxSize.x + 12,
		28
	);

	GUI::DrawPane(noticeOrigin, noticeOrigin + noticeSize);
	GUI::DrawIconByName("$RMB$", iconOrigin);
	GUI::DrawText(text, textOrigin, SColor());
}

void onTick(CRules@ this)
{
	if (v_capped)
	{
		SpecCamera(this);
	}

	if (isCinematic())
	{
		Vec2f mapDim = getMap().getMapDimensions();

		if (this.isMatchRunning())
		{
			CBlob@[]@ importantBlobs = buildImportanceList();
			SortBlobsByImportance(importantBlobs);

			if (!FOCUS_ON_IMPORTANT_BLOBS || !focusOnBlob(importantBlobs))
			{
				CBlob@[] playerBlobs;
				if (getBlobsByTag("player", @playerBlobs))
				{
					posTarget = Vec2f_zero;
					Vec2f minPos = mapDim;
					Vec2f maxPos = Vec2f_zero;

					for (uint i = 0; i < playerBlobs.length; i++)
					{
						CBlob@ blob = playerBlobs[i];
						Vec2f pos = blob.getPosition();

						CBlob@[] blobOverlaps;
						blob.getOverlapping(@blobOverlaps);

						//max distance along each axis
						maxPos.x = Maths::Max(maxPos.x, pos.x);
						maxPos.y = Maths::Max(maxPos.y, pos.y);
						minPos.x = Maths::Min(minPos.x, pos.x);
						minPos.y = Maths::Min(minPos.y, pos.y);

						//sum player positions
						posTarget += pos;
					}

					//mean position of all players
					posTarget /= playerBlobs.length;

					//zoom target
					Vec2f maxDist = maxPos - minPos;
					calculateZoomTarget(maxDist.x, maxDist.y);
				}
				else //no player blobs
				{
					ViewEntireMap();
				}
			}
		}
		else //game not in progress
		{
			ViewEntireMap();
		}
	}

	//right click to toggle cinematic camera
	CControls@ controls = getControls();
	if (
		controls !is null &&								//controls exist
		controls.isKeyJustPressed(KEY_RBUTTON) &&			//right clicked
		(spectatorTeam || getLocalPlayerBlob() is null))	//is in spectator or dead
	{
		if (!isCinematicEnabled())
		{
			SetTargetPlayer(null);
			setCinematicEnabled(true);
			setCinematicForceDisabled(false);
			Sound::Play("Sounds/GUI/menuclick.ogg");
		}
		else
		{
			setCinematicForceDisabled(true);
			Sound::Play("Sounds/GUI/back.ogg");
		}
	}
}
