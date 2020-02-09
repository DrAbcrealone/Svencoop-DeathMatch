namespace TeamDeathMatch
{
    bool bTDMState = false;

    void PluginInit()
    {
        //注册模式
        pvpGameMode::RegistMode("TDM", @StartTeam, @EndTeam, MODE_TEAM);
        pvpClientCmd::RegistCommand("player_team","Change Your Team in Team Death Match","TDM", @TeamDeathMatch::TeamCallBack);

        pvpTeam::AddTeam("Lambda", RGBA(255,165,0,255), CLASS_PLAYER, pvpConfig::getConfig("Team","OrangeSpr").getString());
        pvpTeam::AddTeam("HECU", RGBA(0,255,0,255), CLASS_HUMAN_MILITARY, pvpConfig::getConfig("Team","GreenSpr").getString());
        pvpTeam::AddTeam("XEN", RGBA(255,0,0,255), CLASS_ALIEN_MILITARY, pvpConfig::getConfig("Team","RedSpr").getString());
        pvpTeam::AddTeam("X-Race", RGBA(0,0,255,255), CLASS_XRACE_SHOCK, pvpConfig::getConfig("Team","BlueSpr").getString());
        pvpTeam::RegistTeamMenu("Chose Your Team");
    }

    void TeamCallBack(const CCommand@ Argments)
	{
        if(!bTDMState)
            return;
		CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
		if(bTDMState)
            pvpTeam::TeamMenu.Open(0,0,pPlayer);
	}

    void PlayerDeath(CBasePlayer@ pPlayer, entvars_t@ pevAttacker)
    {
        pvpTeam::CTeam@ pTeam = pvpTeam::GetPlayerTeam(pPlayer);
        if(pTeam is null)
            pvpTeam::TeamMenu.Open(0, 0, pPlayer);
    }

    void StartTeam()
    {
        bTDMState = true;
        pvpEndGame::Restart();
        pvpUtility::SendHLHUDText("Team Death Match");
        pvpUtility::SendHLTitle();
        pvpUtility::OpenMenuAll(pvpTeam::TeamMenu);
        pvpEndGame::addEnd(pvpEndGame::CEndFunc("TeamEnd", @End));
        pvpHitbox::addPostDeath(@PlayerDeath);
    }

    void EndTeam()
    {
        bTDMState = false;
        pvpUtility::SendHLHUDText("Team Death Match Disabled");
        pvpTeam::ClearAllTeam();
        pvpEndGame::delEnd("TeamEnd");
        pvpHitbox::delPostDeath(@PlayerDeath);
    }

    void End()
    {
        if(!bTDMState)
            return;
        pvpTeam::ClearAllTeam();
    }
}