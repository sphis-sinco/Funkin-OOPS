package funkin.ui;

import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import funkin.audio.FunkinSound;
import funkin.input.Controls;
import funkin.modding.IScriptedClass.IEventHandler;
import funkin.modding.PolymodHandler;
import funkin.modding.events.ScriptEvent;
import funkin.modding.module.ModuleHandler;
import funkin.ui.mainmenu.MainMenuState;
import funkin.util.SortUtil;

/**
 * MusicBeatState actually represents the core utility FlxState of the game.
 * It includes functionality for event handling, as well as maintaining BPM-based update events.
 */
@:nullSafety
class MusicBeatState extends FlxTransitionableState implements IEventHandler
{
  var controls(get, never):Controls;

  inline function get_controls():Controls
    return PlayerSettings.player1.controls;

  public var leftWatermarkText:Null<FlxText> = null;
  public var rightWatermarkText:Null<FlxText> = null;

  /**
   * Adds text to the `left` or `right` watermark, changing vertical position with `verticalOffset`
   * @param newtext The text you want to add
   * @param verticalOffset vertical offset, defaults to 0
   * @param id `LEFT` or `RIGHT`, controls what watermark text has the text appended
   */
  public var appendText:Dynamic = function(newtext:String, verticalOffset:Float = 0, id:WatermarkID = LEFT):Void
  {
    var watermarkText:Null<FlxText> = null;

    switch (id)
    {
      case LEFT:
        watermarkText = leftWatermarkText;
      case RIGHT:
        watermarkText = rightWatermarkText;
    }

    watermarkText.text += newtext;
    watermarkText.y += verticalOffset;

    switch (id)
    {
      case LEFT:
        leftWatermarkText.text = watermarkText.text;
        leftWatermarkText.setPosition(watermarkText.x, watermarkText.y);
      case RIGHT:
        rightWatermarkText.text = watermarkText.text;
        rightWatermarkText.setPosition(watermarkText.x, watermarkText.y);
    }
  }

  public var conductorInUse(get, set):Conductor;

  var _conductorInUse:Null<Conductor>;

  function get_conductorInUse():Conductor
  {
    if (_conductorInUse == null) return Conductor.instance;
    return _conductorInUse;
  }

  function set_conductorInUse(value:Conductor):Conductor
  {
    return _conductorInUse = value;
  }

  public function new()
  {
    super();

    initCallbacks();
  }

  function initCallbacks()
  {
    subStateOpened.add(onOpenSubStateComplete);
    subStateClosed.add(onCloseSubStateComplete);
  }

  override function create()
  {
    super.create();

    createWatermarkText();

    Conductor.beatHit.add(this.beatHit);
    Conductor.stepHit.add(this.stepHit);
  }

  public override function destroy():Void
  {
    super.destroy();
    Conductor.beatHit.remove(this.beatHit);
    Conductor.stepHit.remove(this.stepHit);
  }

  function handleFunctionControls():Void
  {
    // Emergency exit button.
    if (FlxG.keys.justPressed.F4) FlxG.switchState(() -> new MainMenuState());
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    dispatchEvent(new UpdateScriptEvent(elapsed));
  }

  override function onFocus():Void
  {
    super.onFocus();

    dispatchEvent(new FocusScriptEvent(FOCUS_GAINED));
  }

  override function onFocusLost():Void
  {
    super.onFocusLost();

    dispatchEvent(new FocusScriptEvent(FOCUS_LOST));
  }

  function createWatermarkText()
  {
    // Both have an xPos of 0, but a width equal to the full screen.
    // The rightWatermarkText is right aligned, which puts the text in the correct spot.
    leftWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);
    rightWatermarkText = new FlxText(0, FlxG.height - 18, FlxG.width, '', 12);

    // 100,000 should be good enough.
    leftWatermarkText.zIndex = 100000;
    rightWatermarkText.zIndex = 100000;
    leftWatermarkText.scrollFactor.set(0, 0);
    rightWatermarkText.scrollFactor.set(0, 0);
    leftWatermarkText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    rightWatermarkText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

    add(leftWatermarkText);
    add(rightWatermarkText);
  }

  public function dispatchEvent(event:ScriptEvent)
  {
    ModuleHandler.callEvent(event);
  }

  function reloadAssets()
  {
    PolymodHandler.forceReloadAssets();

    // Create a new instance of the current state, so old data is cleared.
    FlxG.resetState();
  }

  public function stepHit():Bool
  {
    var event = new SongTimeScriptEvent(SONG_STEP_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  public function beatHit():Bool
  {
    var event = new SongTimeScriptEvent(SONG_BEAT_HIT, conductorInUse.currentBeat, conductorInUse.currentStep);

    dispatchEvent(event);

    if (event.eventCanceled) return false;

    return true;
  }

  /**
   * Refreshes the state, by redoing the render order of all sprites.
   * It does this based on the `zIndex` of each prop.
   */
  public function refresh()
  {
    sort(SortUtil.byZIndex, FlxSort.ASCENDING);
  }

  @:nullSafety(Off)
  override function startOutro(onComplete:() -> Void):Void
  {
    var event = new StateChangeScriptEvent(STATE_CHANGE_BEGIN, null, true);

    dispatchEvent(event);

    if (event.eventCanceled)
    {
      return;
    }
    else
    {
      FunkinSound.stopAllAudio();

      onComplete();
    }
  }

  public override function openSubState(targetSubState:FlxSubState):Void
  {
    var event = new SubStateScriptEvent(SUBSTATE_OPEN_BEGIN, targetSubState, true);

    dispatchEvent(event);

    if (event.eventCanceled) return;

    super.openSubState(targetSubState);
  }

  function onOpenSubStateComplete(targetState:FlxSubState):Void
  {
    dispatchEvent(new SubStateScriptEvent(SUBSTATE_OPEN_END, targetState, true));
  }

  public override function closeSubState():Void
  {
    var event = new SubStateScriptEvent(SUBSTATE_CLOSE_BEGIN, this.subState, true);

    dispatchEvent(event);

    if (event.eventCanceled) return;

    super.closeSubState();
  }

  function onCloseSubStateComplete(targetState:FlxSubState):Void
  {
    dispatchEvent(new SubStateScriptEvent(SUBSTATE_CLOSE_END, targetState, true));
  }
}

enum abstract WatermarkID(String)
{
  var LEFT = 'left';
  var RIGHT = 'right';
}
