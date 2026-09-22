Function Main {
    // Pre-flight checks and lift-off sequence
    local Countdown is 3.
    LaunchCountdown(Countdown).
    PrepareForLaunch().
    InitiateLiftoff().

    // Begin ascent to the target apoapsis with controlled pitch adjustments and coasting to space
    SetLaunchProfile().
    local TargetApoapsis is max(ship:body:atm:height * 1.25, 20000).
    print "Target apoapsis set to " + TargetApoapsis + "m.".
    SuborbitalAscent(TargetApoapsis).
    CoastToSpace().

    // Circularization burn at apoapsis to achieve a stable orbit
    CircularizeOrbit().

    UnlockControls().
}

Function LaunchCountdown {
    Parameter CountdownTime.

    print "Launch countdown initiated... T minus " + CountdownTime + " seconds...".
    wait 1.
    local Counter is CountdownTime.
    until Counter <= 1 {
        set Counter to Counter - 1.
        print Counter + "...".
        wait 1.
    }
}

Function PrepareForLaunch {
    sas off.
    lock throttle to 1.
}

Function InitiateLiftoff {
    PerformStaging().
    print "Booster ignition...".
    wait 1.
    PerformStaging().
    print "Liftoff!".
} 

Function SetLaunchProfile {
    lock TargetPitch to GetPowerLawPitch().
    local TargetDirection is 90.
    lock steering to heading(TargetDirection, TargetPitch).
}

Function SuborbitalAscent {
    Parameter TargetApoapsis.

    local PreviousSpeed is ship:airspeed.
    until apoapsis >= TargetApoapsis {
        AutoStage().
        if PreviousSpeed < 343 and ship:airspeed >= 343 {
            print "Vehicle supersonic!".
        }
        set PreviousSpeed to ship:airspeed.
        wait 0.2.
    } 

    lock throttle to 0.
    lock steering to prograde.
}

Function CoastToSpace {
    wait until ship:altitude >= ship:body:atm:height.
    print "Escaped atmosphere,  coasting to apoapsis...".
}

Function CircularizeOrbit {
    local TotalThrust   is CalculateTotalThrust().
    local TotalMassFlow is CalculateTotalMassFlow().
    local DeltaV        is CalculateDeltaVForCircularization().
    local IspNet        is CalculateNetIsp(TotalThrust, TotalMassFlow).
    local BurnTime      is CalculateBurnTime(DeltaV, IspNet, TotalMassFlow).

    wait until eta:apoapsis < BurnTime / 2.
    print "Initiating circularization burn...".
    local BestEccentricity is ship:orbit:eccentricity.
    local BurnThrottle     is 1.0.
    lock throttle to BurnThrottle.

    until ship:orbit:eccentricity < 0.0005 {
        AutoStage().
        if ship:orbit:eccentricity < 0.05 {
            set BurnThrottle to max(0.05, ship:orbit:eccentricity * 15).
        }
        if ship:orbit:eccentricity > BestEccentricity + 0.0001 {
            break.
        }
        if ship:orbit:eccentricity < BestEccentricity {
            set BestEccentricity to ship:orbit:eccentricity.
        }
        wait 0.2.
    }
    lock throttle to 0.
    wait 1.

    print "Circularization burn complete. Orbit achieved!".
    print "Apoapsis: " + apoapsis + "m".
    print "Periapsis: " + periapsis + "m".
}
    
Function PerformStaging {
    wait until stage:ready.
    stage.
}

Function GetPowerLawPitch {
    local TurnStartAlt is 200.
    local TurnEndAlt   is 60000.
    local InitialPitch is 90.0.
    local FinalPitch   is 0.0.
    local TurnExponent is 0.5.

    if ship:altitude < TurnStartAlt {
        return InitialPitch.
    } else if ship:altitude >= TurnEndAlt {
        return FinalPitch.
    } else {
        local Progress is (ship:altitude - TurnStartAlt) / (TurnEndAlt - TurnStartAlt).
        return InitialPitch - (InitialPitch - FinalPitch) * (Progress ^ TurnExponent).
    }
}

Function AutoStage {
    local EnginesList is list().
    list engines in EnginesList.

    for Engine in EnginesList {
        if HasFlamedOut(Engine) {
            PerformStaging().
            break.
        }
    }
}

Function HasFlamedOut {
    Parameter Engine.

    return Engine:flameout and Engine:ignition.
}

Function CalculateDeltaVForCircularization {
    local Rb        is ship:body:radius.
    local VApoapsis is VisViva(Rb + apoapsis, Rb + (apoapsis + periapsis) / 2).
    local VCircular is VisViva(Rb + apoapsis, Rb + apoapsis).

    return VCircular - VApoapsis.
}

Function CalculateNetIsp {
    Parameter TotalThrust, TotalMassFlow.

    return TotalThrust / (TotalMassFlow * constant:g0).
}

Function CalculateBurnTime {
    Parameter DeltaV, Isp, TotalMassFlow.

    local InititalMass is ship:mass.

    return (InititalMass / TotalMassFlow) * (1 - constant:e ^ (-DeltaV / (Isp * constant:g0))).
}

Function VisViva {
    Parameter RadialDistance, SemiMajorAxis.

    return sqrt(ship:body:mu * ((2 / RadialDistance) - (1 / SemiMajorAxis))).
}

Function CalculateTotalThrust {
    local TotalThrust is 0.
    local EnginesList is list().
    list engines in EnginesList.

    for Engine in EnginesList {
        if IsEngineActive(Engine) {
            set TotalThrust to TotalThrust + Engine:availableThrust.
        }
    }

    return TotalThrust.
}

Function CalculateTotalMassFlow {
    local TotalMassFlow is 0.
    local EnginesList   is list().
    list engines in EnginesList.

    for Engine in EnginesList {
        if IsEngineActive(Engine) {
            set TotalMassFlow to TotalMassFlow + (Engine:availableThrust / (Engine:isp * constant:g0)).
        }
    }

    return TotalMassFlow.
}

Function IsEngineActive {
    Parameter Engine.

    return not Engine:flameout and Engine:ignition.
}

Function UnlockControls {
    unlock throttle.
    unlock steering.
}

Main().