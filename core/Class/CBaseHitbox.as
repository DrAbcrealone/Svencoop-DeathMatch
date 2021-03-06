
//基类
class CBaseHitbox : ScriptBaseMonsterEntity
{
    private Vector m_vecMins,m_vecMaxs;
    private CBasePlayer@ m_pPlayer = null;
    private bool bDeadFlag = false;

    protected Vector m_vecHullmin;
    protected Vector m_vecHullmax;

    CBaseEntity@ OwnerEnt
    {
        get const	{ return g_EntityFuncs.Instance( pev.owner ); }
    }
    
    bool KeyValue( const string& in szKey, const string& in szValue )
    {
        return BaseClass.KeyValue( szKey, szValue );
    }

    void Precache()
    {
        BaseClass.Precache();
        g_Game.PrecacheModel( self, pvpHitbox::strHitbox );
    }

    void Spawn()
    {
        Precache();
        @m_pPlayer = cast<CBasePlayer@>(g_EntityFuncs.Instance(pev.owner));
        g_EntityFuncs.SetModel( self, pvpHitbox::strHitbox );

        if( pev.owner !is null )
        {
            //无敌
            pev.health = Math.FLOAT_MAX;
            //跟随玩家
            pev.movetype	= MOVETYPE_FOLLOW;
            @pev.aiment		= @pev.owner;
            pev.solid		= SOLID_SLIDEBOX;
            pev.colormap	= m_pPlayer.pev.colormap;
            pev.frags       = m_pPlayer.pev.frags;
            self.m_bloodColor	= BLOOD_COLOR_RED;
            self.m_FormattedName = m_pPlayer.pev.netname;
            //设置好team
            pev.team = m_pPlayer.pev.team;

            //隐藏
            if(pvpHitbox::bShowHitbox)
            {
                pev.rendermode = 0;
                pev.renderamt = 100;
            }
            else
            {
                pev.rendermode = kRenderTransTexture;
                pev.renderamt = 0;
            }

            //可受伤害
            pev.flags |= FL_MONSTER;
            pev.takedamage	= DAMAGE_AIM | DAMAGE_YES;
            
            //设置队伍
            self.SetClassification(pev.team == 0 ? CLASS_HUMAN_MILITARY : CLASS(pev.team));

            g_EntityFuncs.SetSize( pev, m_pPlayer.pev.mins, m_pPlayer.pev.maxs );
        }
    }  

    //更新玩家的状态
    void Update()
    {
        pev.movetype	= MOVETYPE_FOLLOW;
        @pev.aiment		= @pev.owner;
        pev.colormap	= m_pPlayer.pev.colormap;
        pev.frags       = m_pPlayer.pev.frags;
        self.m_FormattedName = m_pPlayer.pev.netname;
        //设置好team
        pev.team = m_pPlayer.pev.team;
        //设置队伍
        self.SetClassification(pev.team);
    }

    void Touch(CBaseEntity@ pOther)
    {
        if(pOther.pev.classname == "trigger_hitbox")
        {
            //自动帮你按L,我好良心啊
            pvpUtility::ClientCommand(m_pPlayer, "stuck");
            return;
        } 

        if(pOther.IsBSPModel())
            return;
    }

    int Classify()
    {
        return pev.team;
    }

    //大概是真的死了
    void doDeath(float flTake )
    {
        if( flTake >= m_pPlayer.pev.health * 2.5 && flTake > 60 )
            m_pPlayer.SetAnimation( PLAYER_DIE );
        else
        {	
            m_pPlayer.pev.rendermode = 1;
            m_pPlayer.pev.renderamt = 0;
            g_EntityFuncs.SpawnRandomGibs(m_pPlayer.pev, 1, 1);
            g_SoundSystem.PlaySound(m_pPlayer.edict(), CHAN_AUTO, "common/bodysplat.wav", 1.0f, 1.0f);
        }
        m_pPlayer.pev.health = 0;
        m_pPlayer.pev.armorvalue = 0;
        m_pPlayer.pev.deadflag = DEAD_DYING;
        ++m_pPlayer.m_iDeaths;

        //别忘了摧毁这个Hitbox
        g_EntityFuncs.Remove(self);
    }

    int DeliverDamage(float Ap, float Hp,float Take, entvars_t@ pevAttacker, entvars_t@ pevInflictor, int bitsDamageType)
    {
        CBasePlayer@ pAttacker = cast<CBasePlayer@>(g_EntityFuncs.Instance(pevAttacker));
        CBaseEntity@ pInflictor = g_EntityFuncs.Instance(pevInflictor);
        //扣血扣甲
        m_pPlayer.pev.armorvalue = Ap;
        m_pPlayer.pev.health = Hp;
        m_pPlayer.pev.dmg_take += Take;

        //伤害指示器
        pvpHitbox::sendPanicFeed(m_pPlayer, pevAttacker, pevInflictor);
        //如果死亡将玩家传递死亡，并用keyvalue标记为已死
        if (m_pPlayer.pev.health <= 0)
        {
            bDeadFlag = true;
            //判断死亡类型
            int deathFlag = DEAD_NONE;
            if(pAttacker !is null && pAttacker.IsPlayer() && pAttacker.IsNetClient())
            {
                if( pAttacker !is m_pPlayer )	
                    deathFlag = DEAD_KILLED;
                else
                    deathFlag = DEAD_SUICIDE;
            }
            else if( pevAttacker !is null && g_EntityFuncs.Instance(pevAttacker).IsMonster())
                deathFlag = DEAD_MONSTER;
            else
                deathFlag = DEAD_ACCIDENT;

            //向玩家输出死亡原因
            string szPrintf;
            for ( int i = 1; i <= g_Engine.maxClients; ++i )
		    {
                CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
                if ( pPlayer !is null && pPlayer.IsConnected() )
                {
                    int pIndex = pvpLang::getPlayerLangIndex(pPlayer);
                    switch(deathFlag)
                    {
                        case DEAD_KILLED:
                            szPrintf = string(pAttacker.pev.netname) + " :: ["  + pvpHitbox::doKillFeed(pAttacker, pInflictor, pIndex) + "] :: " + string(m_pPlayer.pev.netname) + "\n";
                            break;
                        case DEAD_SUICIDE:
                            szPrintf = pvpHitbox::doSuicide(m_pPlayer, bitsDamageType, pIndex);
                            break;
                        case DEAD_MONSTER:
                            szPrintf = pvpHitbox::doMonsterKill(m_pPlayer, pInflictor, pIndex);
                            break;
                        case DEAD_ACCIDENT:
                            szPrintf = pvpHitbox::doAccident(m_pPlayer, bitsDamageType, pIndex);
                            break;
                    }
                    //左上角来点输出
                    g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTNOTIFY, szPrintf + "\n");	
	            }
		    }
            //加减分数情况
            switch(deathFlag)
            {
                case DEAD_KILLED: ++pAttacker.pev.frags;break;
                case DEAD_SUICIDE: --m_pPlayer.pev.frags;break;
                default:break;
            }
            //大概是真的死了
            doDeath(Take);
            pvpHook::PostDeath(m_pPlayer, g_EntityFuncs.Instance(pevAttacker));
            //此时返回1
            return 1;
        }
        //0代表正常,玩家未死
        return 0;
    }

    int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
    {
         //人都死了
        if(bDeadFlag)
            return 0;
        
        //摔伤不用这个算
        //才怪
        //if(pevAttacker is null)
        //    return 0;

        //击中友军！重复一遍，击中友军！
        if(pevAttacker.team != 0 && m_pPlayer.pev.team != 0)
        {
            if( g_EntityFuncs.Instance(pevAttacker).IsPlayer() || g_EntityFuncs.Instance(pevAttacker).IsMonster())
            {
                if(pevAttacker.team == pev.team && pevAttacker !is m_pPlayer.pev)
                {
                    pvpHitbox::FriendlyFire(m_pPlayer, pevAttacker);
                    return 0;
                }
            }
        }

        //先修改伤害信息
        //先获取属主血量护甲量
        float pPlayerHp = m_pPlayer.pev.health;
        float pPlayerAp = m_pPlayer.pev.armorvalue;
        if (pPlayerAp != 0 && !(bitsDamageType & (DMG_FALL | DMG_DROWN) != 0) )
	    {
            //从配置中获取减伤率和加成量
            float flARRatio = pvpConfig::getConfig("Hitbox","ARRatio").getFloat();
            float flARBonus = pvpConfig::getConfig("Hitbox","ARBonus").getFloat();
            //计算护甲减伤，算出扣甲量
            float flDamageNew = flDamage * flARRatio;
            float flArmor = (flDamage - flDamageNew) * flARBonus;
            if (flArmor > pPlayerAp)
            {
                flArmor = pPlayerAp;
                flArmor *= (1.0f/flARBonus);
                flDamageNew = flDamage - flArmor;
                pPlayerAp = 0;
            }
            else
                pPlayerAp -= flArmor;
            flDamage = flDamageNew;
        }

        float flTake = flDamage;

        pPlayerHp -= flTake;
        //然后传递给属主
        if(pvpHook::PreTakeDamage(m_pPlayer, pevAttacker, flDamage, bitsDamageType))
            DeliverDamage(pPlayerAp, pPlayerHp, flTake, pevAttacker, pevInflictor, bitsDamageType);
        pvpHook::PostTakeDamage(m_pPlayer);
        //直接结束，不call原来的
        flDamage = 0;//记得清空这个
        bitsDamageType = 0;
        return 1;
    }
}

//注册一个Hitbox
void HitboxRegister()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "CBaseHitbox", "trigger_hitbox" );
	g_Game.PrecacheOther("trigger_hitbox");
    g_Game.PrecacheModel( "sprites/" +  pvpHitbox::strPanic);
    g_Game.PrecacheModel( "sprites/" +  pvpHitbox::strFriendly);
}