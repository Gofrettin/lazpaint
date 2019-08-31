unit UTool;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, BGRABitmap, BGRABitmapTypes, uimage, UImageType,
  ULayerAction, LCLType, Controls, UBrushType, UConfig, LCVectorPolyShapes,
  BGRAGradientScanner, BGRALayerOriginal, LCVectorRectShapes;

type TPaintToolType = (ptHand,ptHotSpot, ptMoveLayer,ptRotateLayer,ptZoomLayer,
                   ptPen, ptBrush, ptClone, ptColorPicker, ptEraser,
                   ptEditShape, ptRect, ptEllipse, ptPolygon, ptSpline,
                   ptFloodFill, ptGradient, ptPhong,
                   ptSelectPen, ptSelectRect, ptSelectEllipse, ptSelectPoly, ptSelectSpline,
                   ptMoveSelection, ptRotateSelection, ptMagicWand, ptDeformation, ptTextureMapping, ptLayerMapping,
                   ptText);

const
  PaintToolTypeStr : array[TPaintToolType] of string = ('Hand','HotSpot', 'MoveLayer','RotateLayer','ZoomLayer',
                   'Pen', 'Brush', 'Clone', 'ColorPicker', 'Eraser',
                   'EditShape', 'Rect', 'Ellipse', 'Polygon', 'Spline',
                   'FloodFill', 'Gradient', 'Phong',
                   'SelectPen', 'SelectRect', 'SelectEllipse', 'SelectPoly', 'SelectSpline',
                   'MoveSelection', 'RotateSelection', 'MagicWand', 'Deformation', 'TextureMapping', 'LayerMapping',
                   'Text');

function StrToPaintToolType(const s: ansistring): TPaintToolType;

type
  TContextualToolbar = (ctColor, ctPenWidth, ctPenStyle, ctAliasing, ctShape, ctEraserOption, ctTolerance,
    ctGradient, ctDeformation, ctLineCap, ctJoinStyle, ctSplineStyle, ctText, ctTextShadow,
    ctPhong, ctAltitude, ctPerspective, ctBrush, ctTexture, ctRatio);
  TContextualToolbars = set of TContextualToolbar;

type
  TToolManager = class;
  TBitmapToVirtualScreenFunction = function(PtF: TPointF): TPointF of object;

  TEraserMode = (emEraseAlpha, emSoften);
  TToolCommand = (tcCut, tcCopy, tcPaste, tcDelete, tcMoveUp, tcMoveDown, tcMoveToFront, tcMoveToBack,
    tcAlignLeft, tcCenterHorizontally, tcAlignRight, tcAlignTop, tcCenterVertically, tcAlignBottom,
    tcShapeToSpline);

function GradientColorSpaceToDisplay(AValue: TBGRAColorInterpolation): string;
function DisplayToGradientColorSpace(AValue: string): TBGRAColorInterpolation;

type
  TLayerKind = (lkUnknown, lkEmpty, lkBitmap, lkTransformedBitmap, lkGradient, lkVectorial, lkSVG, lkOther);

  { TGenericTool }

  TGenericTool = class
  private
    FAction: TLayerAction;
    function GetLayerOffset: TPoint;
  protected
    FManager: TToolManager;
    FLastToolDrawingLayer: TBGRABitmap;
    FValidating, FCanceling: boolean;
    function GetAction: TLayerAction; virtual;
    function GetIdleAction: TLayerAction; virtual;
    function GetIsSelectingTool: boolean; virtual; abstract;
    function FixSelectionTransform: boolean; virtual;
    function FixLayerOffset: boolean; virtual;
    function DoToolDown(toolDest: TBGRABitmap; pt: TPoint; ptF: TPointF; rightBtn: boolean): TRect; virtual;
    function DoToolMove(toolDest: TBGRABitmap; pt: TPoint; ptF: TPointF): TRect; virtual;
    procedure DoToolMoveAfter(pt: TPoint; ptF: TPointF); virtual;
    function DoToolUpdate(toolDest: TBGRABitmap): TRect; virtual;
    procedure OnTryStop(sender: TCustomLayerAction); virtual;
    function SelectionMaxPointDistance: single;
    function GetStatusText: string; virtual;
    function DoGetToolDrawingLayer: TBGRABitmap; virtual;
    function GetCurrentLayerKind: TLayerKind;
  public
    ToolUpdateNeeded: boolean;
    Cursor: TCursor;
    constructor Create(AManager: TToolManager); virtual;
    destructor Destroy; override;
    procedure ValidateAction;
    procedure ValidateActionPartially;
    procedure CancelAction;
    procedure CancelActionPartially;
    procedure BeforeGridSizeChange; virtual;
    procedure AfterGridSizeChange(NewNbX,NewNbY: Integer); virtual;
    function ToolUpdate: TRect;
    function ToolDown(X,Y: single; rightBtn: boolean): TRect;
    function ToolMove(X,Y: single): TRect;
    procedure ToolMoveAfter(X,Y: single);
    function ToolKeyDown(var key: Word): TRect; virtual;
    function ToolKeyUp(var key: Word): TRect; virtual;
    function ToolKeyPress(var key: TUTF8Char): TRect; virtual;
    function ToolUp: TRect; virtual;
    function ToolCommand({%H-}ACommand: TToolCommand): boolean; virtual;
    function ToolProvideCommand({%H-}ACommand: TToolCommand): boolean; virtual;
    function GetContextualToolbars: TContextualToolbars; virtual;
    function GetToolDrawingLayer: TBGRABitmap;
    procedure RestoreBackupDrawingLayer;
    function GetBackupLayerIfExists: TBGRABitmap;
    function Render(VirtualScreen: TBGRABitmap; VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect; virtual;
    property Manager : TToolManager read FManager;
    property IsSelectingTool: boolean read GetIsSelectingTool;
    property Action : TLayerAction read GetAction;
    property LayerOffset : TPoint read GetLayerOffset;
    property LastToolDrawingLayer: TBGRABitmap read FLastToolDrawingLayer;
    property StatusText: string read GetStatusText;
    property Validating: boolean read FValidating;
    property Canceling: boolean read FCanceling;
  end;

  { TReadonlyTool }

  TReadonlyTool = class(TGenericTool)
  protected
    function GetAction: TLayerAction; override;
    function GetIsSelectingTool: boolean; override;
    function DoGetToolDrawingLayer: TBGRABitmap; override;
  end;

  TToolClass = class of TGenericTool;

  TToolPopupMessage= (tpmNone,tpmHoldShiftForSquare, tpmHoldCtrlSnapToPixel,
    tpmReturnValides, tpmBackspaceRemoveLastPoint, tpmCtrlRestrictRotation,
    tpmAltShiftScaleMode, tpmCurveModeHint, tpmBlendOpBackground,
    tpmRightClickForSource);

  TOnToolChangedHandler = procedure(sender: TToolManager; ANewToolType: TPaintToolType) of object;
  TOnPopupToolHandler = procedure(sender: TToolManager; APopupMessage: TToolPopupMessage) of object;

  TShapeOption = (toAliasing, toDrawShape, toFillShape, toCloseShape);
  TShapeOptions = set of TShapeOption;

  { TToolManager }

  TToolManager = class
  private
    FOnColorChanged: TNotifyEvent;
    FOnGradientChanged: TNotifyEvent;
    FOnJoinStyleChanged: TNotifyEvent;
    FOnLineCapChanged: TNotifyEvent;
    FOnPenStyleChanged: TNotifyEvent;
    FOnPenWidthChanged: TNotifyEvent;
    FOnPhongShapeChanged: TNotifyEvent;
    FOnSplineStyleChanged: TNotifyEvent;
    FOnTextFontChanged: TNotifyEvent;
    FOnTextOutlineChanged: TNotifyEvent;
    FOnTextPhongChanged: TNotifyEvent;
    FOnTextShadowChanged: TNotifyEvent;
    FOnTextureChanged: TNotifyEvent;
    FOnShapeOptionChanged: TNotifyEvent;
    FShouldExitTool: boolean;
    FOnToolChangedHandler: TOnToolChangedHandler;
    FOnPopupToolHandler: TOnPopupToolHandler;
    FImage: TLazPaintImage;
    FCurrentTool : TGenericTool;
    FCurrentToolType : TPaintToolType;
    FSleepingTool: TGenericTool;
    FSleepingToolType: TPaintToolType;
    FDeformationGridNbX,FDeformationGridNbY: integer;
    FForeColor, FBackColor: TBGRAPixel;
    FReturnValidatesHintShowed: boolean;
    FTexture: TBGRABitmap;
    FTextureAfterAlpha: TBGRABitmap;
    FTextureOpactiy: byte;
    FBrushInfoList: TList;
    FBrushInfoListChanged: boolean;
    FConfigProvider: IConfigProvider;
    FPenStyle: TPenStyle;
    FJoinStyle: TPenJoinStyle;
    FNormalPenWidth, FEraserWidth: Single;
    FShapeOptions: TShapeOptions;
    FTextFont: TFont;
    FTextOutline: boolean;
    FTextOutlineWidth: single;
    FTextPhong: boolean;
    FTextShadow: boolean;
    FLineCap: TPenEndCap;
    FArrowStart,FArrowEnd: TArrowKind;
    FArrowSize: TPointF;
    FSplineStyle: TSplineStyle;
    FGradientType: TGradientType;
    FGradientSine: boolean;
    FGradientColorspace: TBGRAColorInterpolation;
    FPhongShapeAltitude: integer;
    FPhongShapeBorderSize: integer;
    FPhongShapeKind: TPhongShapeKind;

    function GetCursor: TCursor;
    function GetBackColor: TBGRAPixel;
    function GetBrushAt(AIndex: integer): TLazPaintBrush;
    function GetBrushCount: integer;
    function GetBrushInfo: TLazPaintBrush;
    function GetForeColor: TBGRAPixel;
    function GetShapeOptionAliasing: boolean;
    function GetShapeOptionDraw: boolean;
    function GetShapeOptionFill: boolean;
    function GetPenWidth: single;
    function GetToolSleeping: boolean;
    function GetTextFontName: string;
    function GetTextFontSize: integer;
    function GetTextFontStyle: TFontStyles;
    function GetTextureOpacity: byte;
    procedure SetControlsVisible(Controls: TList; Visible: Boolean);
    procedure SetArrowEnd(AValue: TArrowKind);
    procedure SetArrowSize(AValue: TPointF);
    procedure SetArrowStart(AValue: TArrowKind);
    procedure SetBackColor(AValue: TBGRAPixel);
    procedure SetForeColor(AValue: TBGRAPixel);
    procedure SetGradientColorspace(AValue: TBGRAColorInterpolation);
    procedure SetGradientSine(AValue: boolean);
    procedure SetGradientType(AValue: TGradientType);
    procedure SetJoinStyle(AValue: TPenJoinStyle);
    procedure SetLineCap(AValue: TPenEndCap);
    procedure SetPhongShapeAltitude(AValue: integer);
    procedure SetPhongShapeBorderSize(AValue: integer);
    procedure SetPhongShapeKind(AValue: TPhongShapeKind);
    procedure SetShapeOptions(AValue: TShapeOptions);
    procedure SetPenStyle(AValue: TPenStyle);
    procedure SetPenWidth(AValue: single);
    procedure SetSplineStyle(AValue: TSplineStyle);
    procedure SetTextPhong(AValue: boolean);
    procedure SetTextShadow(AValue: boolean);
    procedure SetTextureOpacity(AValue: byte);
    procedure ToolCloseAndReopenImmediatly;
  protected
    function CheckExitTool: boolean;
    procedure NotifyImageOrSelectionChanged(ALayer: TBGRABitmap; ARect: TRect);
    procedure InternalSetCurrentToolType(tool: TPaintToolType);
    function InternalBitmapToVirtualScreen(PtF: TPointF): TPointF;
    function AddLayerOffset(ARect: TRect) : TRect;
  public
    BitmapToVirtualScreen: TBitmapToVirtualScreenFunction;
    PenWidthControls, AliasingControls, EraserControls, ToleranceControls,
    ShapeControls, PenStyleControls, JoinStyleControls, SplineStyleControls,
    CloseShapeControls, LineCapControls, GradientControls, DeformationControls,
    TextControls, TextShadowControls, PhongControls, AltitudeControls,
    PerspectiveControls,PenColorControls,TextureControls,
    BrushControls, RatioControls: TList;

    BlackAndWhite: boolean;

    //tools configuration
    ToolEraserMode: TEraserMode;
    ToolCurrentCursorPos: TPointF;
    ToolEraserAlpha, ToolTolerance: byte;
    ToolFloodFillOptionProgressive: boolean;
    ToolPerspectiveRepeat,ToolPerspectiveTwoPlanes: boolean;
    ToolDeformationGridMoveWithoutDeformation: boolean;
    TextShadowBlurRadius: single;
    TextShadowOffset: TPoint;
    LightPosition: TPointF;
    LightAltitude: integer;
    ToolTextAlign: TAlignment;
    ToolBrushInfoIndex: integer;
    ToolBrushSpacing: integer;
    ToolPressure: single;
    ToolRatio: Single;

    constructor Create(AImage: TLazPaintImage; AConfigProvider: IConfigProvider; ABitmapToVirtualScreen: TBitmapToVirtualScreenFunction = nil; ABlackAndWhite : boolean = false);
    destructor Destroy; override;
    procedure LoadFromConfig;
    procedure SaveToConfig;
    procedure ReloadBrushes;
    procedure SaveBrushes;
    function ApplyPressure(AColor: TBGRAPixel): TBGRAPixel;
    procedure SetPressure(APressure: single);

    function GetCurrentToolType: TPaintToolType;
    function SetCurrentToolType(tool: TPaintToolType): boolean;
    procedure UpdateContextualToolbars;
    function ToolCanBeUsed: boolean;
    procedure ToolWakeUp;
    procedure ToolSleep;

    function ToolDown(X,Y: single; ARightBtn: boolean; APressure: single): boolean; overload;
    function ToolMove(X,Y: single; APressure: single): boolean; overload;
    procedure ToolMoveAfter(X,Y: single); overload;
    function ToolDown(ACoord: TPointF; ARightBtn: boolean; APressure: single): boolean; overload;
    function ToolMove(ACoord: TPointF; APressure: single): boolean; overload;
    procedure ToolMoveAfter(coord: TPointF); overload;
    function ToolKeyDown(var key: Word): boolean;
    function ToolKeyUp(var key: Word): boolean;
    function ToolKeyPress(var key: TUTF8Char): boolean;
    function ToolCommand(ACommand: TToolCommand): boolean; virtual;
    function ToolProvideCommand(ACommand: TToolCommand): boolean; virtual;
    function ToolUp: boolean;
    procedure ToolCloseDontReopen;
    procedure ToolOpen;
    function ToolUpdate: boolean;
    function ToolUpdateNeeded: boolean;
    procedure ToolPopup(AMessage: TToolPopupMessage);
    procedure HintReturnValidates;

    function IsSelectingTool: boolean;
    function DisplayFilledSelection: boolean;
    procedure QueryExitTool;

    procedure RenderTool(formBitmap: TBGRABitmap);
    function GetRenderBounds(VirtualScreenWidth, VirtualScreenHeight: integer): TRect;

    property Image: TLazPaintImage read FImage;
    property CurrentTool: TGenericTool read FCurrentTool;

    property DeformationGridNbX: integer read FDeformationGridNbX;
    property DeformationGridNbY: integer read FDeformationGridNbY;
    property ForeColor: TBGRAPixel read GetForeColor write SetForeColor;
    property BackColor: TBGRAPixel read GetBackColor write SetBackColor;

    function SetDeformationGridSize(NbX,NbY: integer): boolean;
    procedure SwapToolColors;
    procedure SetTexture(ATexture: TBGRABitmap); overload;
    procedure SetTexture(ATexture: TBGRABitmap; AOpacity: byte); overload;
    function GetTextureAfterAlpha: TBGRABitmap;
    function GetTexture: TBGRABitmap;
    function BorrowTexture: TBGRABitmap;
    procedure AddBrush(brush: TLazPaintBrush);
    procedure RemoveBrushAt(index: integer);
    procedure SetTextFont(AName: string; ASize: integer; AStyle: TFontStyles);
    procedure SetTextFont(AFont: TFont);
    function GetTextFont: TFont;
    procedure SetTextOutline(AEnabled: boolean; AWidth: single);

    property OnToolChanged: TOnToolChangedHandler read FOnToolChangedHandler write FOnToolChangedHandler;
    property OnPopup: TOnPopupToolHandler read FOnPopupToolHandler write FOnPopupToolHandler;
    property OnTextureChanged: TNotifyEvent read FOnTextureChanged write FOnTextureChanged;
    property OnColorChanged: TNotifyEvent read FOnColorChanged write FOnColorChanged;
    property OnPenWidthChanged: TNotifyEvent read FOnPenWidthChanged write FOnPenWidthChanged;
    property OnPenStyleChanged: TNotifyEvent read FOnPenStyleChanged write FOnPenStyleChanged;
    property OnJoinStyleChanged: TNotifyEvent read FOnJoinStyleChanged write FOnJoinStyleChanged;
    property OnShapeOptionChanged: TNotifyEvent read FOnShapeOptionChanged write FOnShapeOptionChanged;
    property OnTextFontChanged: TNotifyEvent read FOnTextFontChanged write FOnTextFontChanged;
    property OnTextOutlineChanged: TNotifyEvent read FOnTextOutlineChanged write FOnTextOutlineChanged;
    property OnTextPhongChanged: TNotifyEvent read FOnTextPhongChanged write FOnTextPhongChanged;
    property OnTextShadowChanged: TNotifyEvent read FOnTextShadowChanged write FOnTextShadowChanged;
    property OnLineCapChanged: TNotifyEvent read FOnLineCapChanged write FOnLineCapChanged;
    property OnSplineStyleChanged: TNotifyEvent read FOnSplineStyleChanged write FOnSplineStyleChanged;
    property OnGradientChanged: TNotifyEvent read FOnGradientChanged write FOnGradientChanged;
    property OnPhongShapeChanged: TNotifyEvent read FOnPhongShapeChanged write FOnPhongShapeChanged;
    property Cursor: TCursor read GetCursor;
    property ToolSleeping: boolean read GetToolSleeping;
    property TextureOpacity: byte read GetTextureOpacity write SetTextureOpacity;
    property PenWidth: single read GetPenWidth write SetPenWidth;
    property PenStyle: TPenStyle read FPenStyle write SetPenStyle;
    property JoinStyle: TPenJoinStyle read FJoinStyle write SetJoinStyle;
    property ShapeOptions: TShapeOptions read FShapeOptions write SetShapeOptions;
    property ShapeOptionDraw: boolean read GetShapeOptionDraw;
    property ShapeOptionFill: boolean read GetShapeOptionFill;
    property ShapeOptionAliasing: boolean read GetShapeOptionAliasing;
    property BrushInfo: TLazPaintBrush read GetBrushInfo;
    property BrushAt[AIndex: integer]: TLazPaintBrush read GetBrushAt;
    property BrushCount: integer read GetBrushCount;
    property TextFontName: string read GetTextFontName;
    property TextFontSize: integer read GetTextFontSize;
    property TextFontStyle: TFontStyles read GetTextFontStyle;
    property TextOutline: boolean read FTextOutline;
    property TextOutlineWidth: single read FTextOutlineWidth;
    property TextPhong: boolean read FTextPhong write SetTextPhong;
    property LineCap: TPenEndCap read FLineCap write SetLineCap;
    property ArrowStart: TArrowKind read FArrowStart write SetArrowStart;
    property ArrowEnd: TArrowKind read FArrowEnd write SetArrowEnd;
    property ArrowSize: TPointF read FArrowSize write SetArrowSize;
    property SplineStyle: TSplineStyle read FSplineStyle write SetSplineStyle;
    property GradientType: TGradientType read FGradientType write SetGradientType;
    property GradientSine: boolean read FGradientSine write SetGradientSine;
    property GradientColorspace: TBGRAColorInterpolation read FGradientColorspace write SetGradientColorspace;
    property TextShadow: boolean read FTextShadow write SetTextShadow;
    property PhongShapeAltitude: integer read FPhongShapeAltitude write SetPhongShapeAltitude;
    property PhongShapeBorderSize: integer read FPhongShapeBorderSize write SetPhongShapeBorderSize;
    property PhongShapeKind: TPhongShapeKind read FPhongShapeKind write SetPhongShapeKind;
   end;

procedure RegisterTool(ATool: TPaintToolType; AClass: TToolClass);
function ToolPopupMessageToStr(AMessage :TToolPopupMessage): string;

implementation

uses Types, ugraph, LCScaleDPI, LazPaintType, UCursors, BGRATextFX, ULoading, uresourcestrings,
  BGRATransform, LCVectorOriginal, BGRAGradientOriginal, BGRASVGOriginal;

function StrToPaintToolType(const s: ansistring): TPaintToolType;
var pt: TPaintToolType;
    ls: ansistring;
begin
  result := ptHand;
  ls:= LowerCase(s);
  for pt := low(TPaintToolType) to high(TPaintToolType) do
    if ls = LowerCase(PaintToolTypeStr[pt]) then
    begin
      result := pt;
      break;
    end;
end;

function GradientColorSpaceToDisplay(AValue: TBGRAColorInterpolation): string;
begin
  case AValue of
    ciStdRGB: result := rsLinearRGB;
    ciLinearHSLPositive: result := rsHueCW;
    ciLinearHSLNegative: result := rsHueCCW;
    ciGSBPositive: result := rsCorrectedHueCW;
    ciGSBNegative: result := rsCorrectedHueCCW;
  else
    result := rsRGB;
  end;
end;

function DisplayToGradientColorSpace(AValue: string): TBGRAColorInterpolation;
begin
  if AValue=rsLinearRGB then result := ciStdRGB else
  if AValue=rsHueCW then result := ciLinearHSLPositive else
  if AValue=rsHueCCW then result := ciLinearHSLNegative else
  if AValue=rsCorrectedHueCW then result := ciGSBPositive else
  if AValue=rsCorrectedHueCCW then result := ciGSBNegative
  else
    result := ciLinearRGB;
end;

var
   PaintTools: array[TPaintToolType] of TToolClass;

procedure RegisterTool(ATool: TPaintToolType; AClass: TToolClass);
begin
  PaintTools[ATool] := AClass;
end;

function ToolPopupMessageToStr(AMessage: TToolPopupMessage): string;
begin
  case AMessage of
  tpmHoldShiftForSquare: result := rsHoldShiftForSquare;
  tpmHoldCtrlSnapToPixel: result := rsHoldCtrlSnapToPixel;
  tpmReturnValides: result := rsReturnValides;
  tpmBackspaceRemoveLastPoint: result := rsBackspaceRemoveLastPoint;
  tpmCtrlRestrictRotation: result := rsCtrlRestrictRotation;
  tpmAltShiftScaleMode: result := rsAltShiftScaleMode;
  tpmCurveModeHint: result := rsCurveModeHint;
  tpmBlendOpBackground: result := rsBlendOpNotUsedForBackground;
  tpmRightClickForSource: result := rsRightClickForSource;
  else
    result := '';
  end;
end;

{ TReadonlyTool }

function TReadonlyTool.GetAction: TLayerAction;
begin
  Result:= nil;
end;

function TReadonlyTool.GetIsSelectingTool: boolean;
begin
  result := false;
end;

function TReadonlyTool.DoGetToolDrawingLayer: TBGRABitmap;
begin
  if Manager.Image.SelectionMaskEmpty or not assigned(Manager.Image.SelectionLayerReadonly) then
    Result:= Manager.Image.CurrentLayerReadOnly
  else
    Result:= Manager.Image.SelectionLayerReadonly;
end;

procedure TToolManager.HintReturnValidates;
begin
  if not FReturnValidatesHintShowed then
  begin
    ToolPopup(tpmReturnValides);
    FReturnValidatesHintShowed:= true;
  end;
end;

{ TGenericTool }

{$hints off}

function TGenericTool.GetLayerOffset: TPoint;
begin
  if IsSelectingTool or not Assigned(Manager.Image) then
    result := Point(0,0)
  else
    if GetToolDrawingLayer = Manager.Image.CurrentLayerReadOnly then
      result := Manager.Image.LayerOffset[Manager.Image.CurrentLayerIndex]
    else
      result := Point(0,0);
end;

function TGenericTool.GetStatusText: string;
begin
  result := '';
end;

function TGenericTool.DoGetToolDrawingLayer: TBGRABitmap;
begin
  if Action = nil then
    result := nil
  else if IsSelectingTool then
  begin
    Action.QuerySelection;
    result := Action.CurrentSelection;
    if result = nil then
      raise exception.Create('Selection not created');
  end
  else
    result := Action.DrawingLayer;
end;

function TGenericTool.GetCurrentLayerKind: TLayerKind;
var
  c: TBGRALayerOriginalAny;
begin
  if not Manager.Image.LayerOriginalDefined[Manager.Image.CurrentLayerIndex] then
  begin
    if Manager.Image.CurrentLayerEmpty then exit(lkEmpty)
    else exit(lkBitmap);
  end else
  if not Manager.Image.LayerOriginalKnown[Manager.Image.CurrentLayerIndex] then
   exit(lkUnknown)
  else
  begin
    c := Manager.Image.LayerOriginalClass[Manager.Image.CurrentLayerIndex];
    if c = TVectorOriginal then exit(lkVectorial) else
    if c = TBGRALayerImageOriginal then exit(lkTransformedBitmap) else
    if c = TBGRALayerGradientOriginal then exit(lkGradient) else
    if c = TBGRALayerSVGOriginal then exit(lkSVG) else
      exit(lkOther);
  end;
end;

function TGenericTool.GetAction: TLayerAction;
begin
  if not Assigned(FAction) then
  begin
    FAction := Manager.Image.CreateAction(not IsSelectingTool And Manager.Image.SelectionMaskEmpty,
                                          IsSelectingTool or not Manager.Image.SelectionMaskEmpty);
    FAction.OnTryStop := @OnTryStop;
    FAction.ChangeBoundsNotified:= true;
  end;
  result := FAction;
end;

function TGenericTool.GetIdleAction: TLayerAction;
begin
  if not Assigned(FAction) then
  begin
    FAction := Manager.Image.CreateAction(false);
    FAction.OnTryStop := @OnTryStop;
    FAction.ChangeBoundsNotified:= true;
  end;
  result := FAction;
end;

function TGenericTool.FixSelectionTransform: boolean;
begin
  result:= true;
end;

function TGenericTool.FixLayerOffset: boolean;
begin
  result:= true;
end;

function TGenericTool.DoToolDown(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF; rightBtn: boolean): TRect;
begin
  result := EmptyRect;
end;
{$hints on}

{$hints off}
function TGenericTool.DoToolMove(toolDest: TBGRABitmap; pt: TPoint; ptF: TPointF): TRect;
begin
  result := EmptyRect;
end;
{$hints on}

{$hints off}
procedure TGenericTool.DoToolMoveAfter(pt: TPoint; ptF: TPointF);
begin
  //nothing
end;

{$hints on}

constructor TGenericTool.Create(AManager: TToolManager);
begin
  inherited Create;
  FManager := AManager;
  FAction := nil;
  Cursor := crDefault;
end;

destructor TGenericTool.Destroy;
begin
  FAction.Free;
  inherited Destroy;
end;

procedure TGenericTool.ValidateAction;
begin
  if Assigned(FAction) then
  begin
    FValidating := true;
    FAction.Validate;
    FValidating := false;
    FreeAndNil(FAction);
  end;
end;

procedure TGenericTool.ValidateActionPartially;
begin
  if Assigned(FAction) then
  begin
    FValidating := true;
    FAction.PartialValidate;
    FValidating := false;
  end;
end;

procedure TGenericTool.CancelAction;
begin
  if FAction <> nil then
  begin
    FCanceling := true;
    FreeAndNil(FAction);
    FCanceling := false;
  end;
end;

procedure TGenericTool.CancelActionPartially;
begin
  if Assigned(FAction) then
  begin
    FCanceling := true;
    FAction.PartialCancel;
    FCanceling := false;
  end;
end;

procedure TGenericTool.BeforeGridSizeChange;
begin
  //nothing
end;

{$hints off}
function TGenericTool.DoToolUpdate(toolDest: TBGRABitmap): TRect;
begin
  result := EmptyRect;
  //nothing
end;

procedure TGenericTool.OnTryStop(sender: TCustomLayerAction);
begin
  Manager.ToolCloseAndReopenImmediatly;
end;

function TGenericTool.SelectionMaxPointDistance: single;
begin
  result := DoScaleX(10,OriginalDPI);
  result /= Manager.Image.ZoomFactor;
end;

procedure TGenericTool.AfterGridSizeChange(NewNbX,NewNbY: Integer);
begin
 //nothing
end;

{$hints on}

function TGenericTool.ToolUpdate: TRect;
var toolDest :TBGRABitmap;
begin
  toolDest := GetToolDrawingLayer;
  if toolDest = nil then
  begin
    result := EmptyRect;
    exit;
  end;
  toolDest.JoinStyle := Manager.JoinStyle;
  toolDest.LineCap := Manager.LineCap;
  toolDest.PenStyle := Manager.PenStyle;
  result := DoToolUpdate(toolDest);
end;

function TGenericTool.ToolDown(X, Y: single; rightBtn: boolean): TRect;
var
  toolDest: TBGRABitmap;
  ptF: TPointF;
begin
  result := EmptyRect;
  toolDest := GetToolDrawingLayer;
  if toolDest = nil then exit;
  toolDest.JoinStyle := Manager.JoinStyle;
  toolDest.LineCap := Manager.LineCap;
  toolDest.PenStyle := Manager.PenStyle;
  ptF := PointF(x,y);
  if toolDest = Manager.Image.CurrentLayerReadOnly then
  begin
    if FixLayerOffset then
    begin
      ptF.x -= LayerOffset.x;
      ptF.y -= LayerOffset.y;
    end;
  end else if FixSelectionTransform and ((toolDest = Manager.Image.SelectionMaskReadonly)
    or (toolDest = Manager.Image.SelectionLayerReadonly)) and
      IsAffineMatrixInversible(Manager.Image.SelectionTransform) then
    ptF := AffineMatrixInverse(Manager.Image.SelectionTransform)*ptF;

  result := DoToolDown(toolDest,ptF.Round,ptF,rightBtn);
end;

function TGenericTool.ToolMove(X, Y: single): TRect;
var
  toolDest: TBGRABitmap;
  ptF: TPointF;
begin
  ptF := PointF(x,y);
  Manager.ToolCurrentCursorPos := ptF;
  result := EmptyRect;
  toolDest := GetToolDrawingLayer;
  if toolDest = nil then exit;
  toolDest.JoinStyle := Manager.JoinStyle;
  toolDest.LineCap := Manager.LineCap;
  toolDest.PenStyle := Manager.PenStyle;
  if toolDest = Manager.Image.CurrentLayerReadOnly then
  begin
    if FixLayerOffset then
    begin
      ptF.x -= LayerOffset.x;
      ptF.y -= LayerOffset.y;
    end;
  end else if FixSelectionTransform and ((toolDest = Manager.Image.SelectionMaskReadonly)
    or (toolDest = Manager.Image.SelectionLayerReadonly)) and
      IsAffineMatrixInversible(Manager.Image.SelectionTransform) then
    ptF := AffineMatrixInverse(Manager.Image.SelectionTransform)*ptF;

  result := DoToolMove(toolDest,ptF.Round,ptF);
end;

procedure TGenericTool.ToolMoveAfter(X, Y: single);
var
  pt: TPoint;
  ptF: TPointF;
begin
  if FixLayerOffset then
  begin
    x -= LayerOffset.x;
    y -= LayerOffset.y;
  end;
  pt := Point(round(x),round(y));
  ptF := PointF(x,y);
  DoToolMoveAfter(pt,ptF);
end;

{$hints off}
function TGenericTool.ToolKeyDown(var key: Word): TRect;
begin
  result := EmptyRect;
  //defined later
end;

function TGenericTool.ToolKeyUp(var key: Word): TRect;
begin
  result := EmptyRect;
  //defined later
end;

function TGenericTool.ToolKeyPress(var key: TUTF8Char): TRect;
begin
  result := EmptyRect;
  //defined later
end;

{$hints on}

function TGenericTool.ToolUp: TRect;
begin
  result := EmptyRect;
  //defined later
end;

function TGenericTool.ToolCommand(ACommand: TToolCommand): boolean;
begin
  result := false;
end;

function TGenericTool.ToolProvideCommand(ACommand: TToolCommand): boolean;
begin
  result := false;
end;

function TGenericTool.GetContextualToolbars: TContextualToolbars;
begin
  result := [ctColor,ctTexture];
end;

function TGenericTool.GetToolDrawingLayer: TBGRABitmap;
begin
  result := DoGetToolDrawingLayer;
  FLastToolDrawingLayer := result;
end;

procedure TGenericTool.RestoreBackupDrawingLayer;
begin
  if Assigned(FAction) then
  begin
    if IsSelectingTool then
      Action.RestoreSelectionMask
    else
      Action.RestoreDrawingLayer;
  end;
end;

function TGenericTool.GetBackupLayerIfExists: TBGRABitmap;
begin
  if Action = nil then
  begin
    result := nil;
    exit;
  end;
  if IsSelectingTool then
    result := Action.BackupSelection
  else
    result := Action.BackupDrawingLayer;
end;

{$hints off}
function TGenericTool.Render(VirtualScreen: TBGRABitmap; VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect;
begin
  result := EmptyRect;
end;

{$hints on}

{ TToolManager }

function TToolManager.GetCurrentToolType: TPaintToolType;
begin
  result := FCurrentToolType;
end;

function TToolManager.SetCurrentToolType(tool: TPaintToolType): boolean;
begin
  if not ToolSleeping then
  begin
    InternalSetCurrentToolType(tool);
    result := true;
  end
  else result := false;
end;

procedure TToolManager.SetControlsVisible(Controls: TList; Visible: Boolean);
var i: integer;
begin
  if Visible then
  begin
    for i := 0 to Controls.Count-1 do
      (TObject(Controls[i]) as TControl).Visible := Visible;
  end else
  begin
    for i := Controls.Count-1 downto 0 do
      (TObject(Controls[i]) as TControl).Visible := Visible;
  end;
end;

procedure TToolManager.SetArrowEnd(AValue: TArrowKind);
begin
  if FArrowEnd=AValue then Exit;
  FArrowEnd:=AValue;
  if Assigned(FOnLineCapChanged) then FOnLineCapChanged(self);
end;

procedure TToolManager.SetArrowSize(AValue: TPointF);
begin
  if FArrowSize=AValue then Exit;
  FArrowSize:=AValue;
  if Assigned(FOnLineCapChanged) then FOnLineCapChanged(self);
end;

procedure TToolManager.SetArrowStart(AValue: TArrowKind);
begin
  if FArrowStart=AValue then Exit;
  FArrowStart:=AValue;
  if Assigned(FOnLineCapChanged) then FOnLineCapChanged(self);
end;

procedure TToolManager.SetBackColor(AValue: TBGRAPixel);
begin
  if (AValue.red = FBackColor.red) and
     (AValue.green = FBackColor.green) and
     (AValue.blue = FBackColor.blue) and
     (AValue.alpha = FBackColor.alpha) then exit;
  FBackColor := AValue;
  if Assigned(FOnColorChanged) then FOnColorChanged(self);
end;

procedure TToolManager.SetForeColor(AValue: TBGRAPixel);
begin
  if (AValue.red = FForeColor.red) and
     (AValue.green = FForeColor.green) and
     (AValue.blue = FForeColor.blue) and
     (AValue.alpha = FForeColor.alpha) then exit;
  FForeColor := AValue;
  if Assigned(FOnColorChanged) then FOnColorChanged(self);
end;

procedure TToolManager.SetGradientColorspace(AValue: TBGRAColorInterpolation);
begin
  if FGradientColorspace=AValue then Exit;
  FGradientColorspace:=AValue;
  if Assigned(FOnGradientChanged) then FOnGradientChanged(self);
end;

procedure TToolManager.SetGradientSine(AValue: boolean);
begin
  if FGradientSine=AValue then Exit;
  FGradientSine:=AValue;
  if Assigned(FOnGradientChanged) then FOnGradientChanged(self);
end;

procedure TToolManager.SetGradientType(AValue: TGradientType);
begin
  if FGradientType=AValue then Exit;
  FGradientType:=AValue;
  if Assigned(FOnGradientChanged) then FOnGradientChanged(self);
end;

procedure TToolManager.SetJoinStyle(AValue: TPenJoinStyle);
begin
  if FJoinStyle=AValue then Exit;
  FJoinStyle:=AValue;
  if Assigned(FOnJoinStyleChanged) then FOnJoinStyleChanged(self);
end;

procedure TToolManager.SetLineCap(AValue: TPenEndCap);
begin
  if FLineCap=AValue then Exit;
  FLineCap:=AValue;
  if Assigned(FOnLineCapChanged) then FOnLineCapChanged(self);
end;

procedure TToolManager.SetPhongShapeAltitude(AValue: integer);
begin
  if FPhongShapeAltitude=AValue then Exit;
  FPhongShapeAltitude:=AValue;
  if Assigned(FOnPhongShapeChanged) then FOnPhongShapeChanged(self);
end;

procedure TToolManager.SetPhongShapeBorderSize(AValue: integer);
begin
  if FPhongShapeBorderSize=AValue then Exit;
  FPhongShapeBorderSize:=AValue;
  if Assigned(FOnPhongShapeChanged) then FOnPhongShapeChanged(self);
end;

procedure TToolManager.SetPhongShapeKind(AValue: TPhongShapeKind);
begin
  if FPhongShapeKind=AValue then Exit;
  FPhongShapeKind:=AValue;
  if Assigned(FOnPhongShapeChanged) then FOnPhongShapeChanged(self);
end;

procedure TToolManager.SetShapeOptions(AValue: TShapeOptions);
begin
  if FShapeOptions=AValue then Exit;
  FShapeOptions:=AValue;
  if Assigned(FOnShapeOptionChanged) then FOnShapeOptionChanged(self);
end;

procedure TToolManager.SetPenStyle(AValue: TPenStyle);
begin
  if FPenStyle=AValue then Exit;
  FPenStyle:=AValue;
  if Assigned(FOnPenStyleChanged) then FOnPenStyleChanged(self);
end;

procedure TToolManager.SetPenWidth(AValue: single);
begin
  if GetCurrentToolType = ptEraser then
  begin
    if FEraserWidth <> AValue then
    begin
      FEraserWidth := AValue;
      if Assigned(FOnPenWidthChanged) then FOnPenWidthChanged(self);
    end;
  end else
  begin
    if FNormalPenWidth <> AValue then
    begin
      FNormalPenWidth := AValue;
      if Assigned(FOnPenWidthChanged) then FOnPenWidthChanged(self);
    end;
  end;
end;

procedure TToolManager.SetSplineStyle(AValue: TSplineStyle);
begin
  if FSplineStyle=AValue then Exit;
  FSplineStyle:=AValue;
  if Assigned(FOnSplineStyleChanged) then FOnSplineStyleChanged(self);
end;

procedure TToolManager.SetTextPhong(AValue: boolean);
begin
  if FTextPhong=AValue then Exit;
  FTextPhong:=AValue;
  if Assigned(FOnTextPhongChanged) then FOnTextPhongChanged(self);
end;

procedure TToolManager.SetTextShadow(AValue: boolean);
begin
  if FTextShadow=AValue then Exit;
  FTextShadow:=AValue;
  if Assigned(FOnTextShadowChanged) then FOnTextShadowChanged(self);
end;

procedure TToolManager.SetTextureOpacity(AValue: byte);
begin
  if AValue = FTextureOpactiy then exit;
  FreeAndNil(FTextureAfterAlpha);
  FTextureOpactiy := AValue;
  if Assigned(FOnTextureChanged) then FOnTextureChanged(self);
end;

function TToolManager.CheckExitTool: boolean;
begin
  if FShouldExitTool then
  begin
    FShouldExitTool:= false;
    if FCurrentToolType in[ptRect,ptEllipse,ptPolygon,ptSpline,ptText,ptPhong,ptGradient] then
      SetCurrentToolType(ptEditShape)
    else
      SetCurrentToolType(ptHand);
    result := true;
  end else
    result := false;
end;

procedure TToolManager.NotifyImageOrSelectionChanged(ALayer: TBGRABitmap; ARect: TRect);
begin
  if (CurrentTool <> nil) and not IsRectEmpty(ARect) then
  begin
    if Assigned(CurrentTool.FAction) then
      if not IsOnlyRenderChange(ARect) then
        CurrentTool.FAction.NotifyChange(ALayer, ARect);

    if Assigned(ALayer) then
    begin
      if ALayer = Image.CurrentLayerReadOnly then
        Image.ImageMayChange(AddLayerOffset(ARect))
      else
        Image.LayerMayChange(ALayer, ARect);
    end
  end;
end;

function TToolManager.ToolCanBeUsed: boolean;
begin
  result := (currentTool <> nil) and ((FCurrentToolType = ptHand) or CurrentTool.IsSelectingTool or Image.CurrentLayerVisible);
end;

function TToolManager.GetBackColor: TBGRAPixel;
begin
  if BlackAndWhite then
    result := BGRAToGrayscale(FBackColor)
  else
    result := FBackColor;
end;

function TToolManager.GetBrushAt(AIndex: integer): TLazPaintBrush;
begin
  if (FBrushInfoList = nil) or (AIndex < 0) or (AIndex >= FBrushInfoList.Count) then
    result := nil
  else
    result := TObject(FBrushInfoList[AIndex]) as TLazPaintBrush;
end;

function TToolManager.GetBrushCount: integer;
begin
  if Assigned(FBrushInfoList) then
    result := FBrushInfoList.Count
  else
    result := 0;
end;

function TToolManager.GetBrushInfo: TLazPaintBrush;
begin
  if (ToolBrushInfoIndex < 0) or (ToolBrushInfoIndex > FBrushInfoList.Count) then
    ToolBrushInfoIndex := 0;
  if ToolBrushInfoIndex > FBrushInfoList.Count then
    result := nil
  else
    result := TObject(FBrushInfoList[ToolBrushInfoIndex]) as TLazPaintBrush;
end;

function TToolManager.GetCursor: TCursor;
var toolCursor: TCursor;
begin
  case GetCurrentToolType of
  ptHand, ptMoveSelection, ptZoomLayer: result := crSizeAll;
  ptRotateSelection,ptRotateLayer: result := crCustomRotate;
  ptPen,ptBrush,ptClone: result := crCustomCrosshair;
  ptRect,ptEllipse,ptSelectRect,ptSelectEllipse: result := crCustomCrosshair;
  ptColorPicker: result := crCustomColorPicker;
  ptFloodFill: result := crCustomFloodfill;
  ptSelectPen: result := crHandPoint;
  ptEraser: result := crDefault;
  else result := crDefault;
  end;

  if CurrentTool <> nil then
    toolCursor := CurrentTool.Cursor
  else
    toolCursor := crDefault;
  if toolCursor <> crDefault then result := toolCursor;
end;

function TToolManager.GetForeColor: TBGRAPixel;
begin
  if BlackAndWhite then
    result := BGRAToGrayscale(FForeColor)
  else
    result := FForeColor;
end;

function TToolManager.GetShapeOptionAliasing: boolean;
begin
  result := toAliasing in FShapeOptions;
end;

function TToolManager.GetShapeOptionDraw: boolean;
begin
  result := toDrawShape in FShapeOptions;
end;

function TToolManager.GetShapeOptionFill: boolean;
begin
  result := toFillShape in FShapeOptions;
end;

function TToolManager.GetPenWidth: single;
begin
  if GetCurrentToolType = ptEraser then
    result := FEraserWidth else result := FNormalPenWidth;
end;

function TToolManager.GetToolSleeping: boolean;
begin
  result := FSleepingTool <> nil;
end;

function TToolManager.GetTextFontName: string;
begin
  result := FTextFont.Name;
end;

function TToolManager.GetTextFontSize: integer;
begin
  result := FTextFont.Size;
end;

function TToolManager.GetTextFontStyle: TFontStyles;
begin
  result := FTextFont.Style;
end;

function TToolManager.GetTextureOpacity: byte;
begin
  result := FTextureOpactiy;
end;

constructor TToolManager.Create(AImage: TLazPaintImage; AConfigProvider: IConfigProvider; ABitmapToVirtualScreen: TBitmapToVirtualScreenFunction; ABlackAndWhite : boolean);
begin
  FImage:= AImage;
  BitmapToVirtualScreen := ABitmapToVirtualScreen;
  FShouldExitTool:= false;
  FConfigProvider := AConfigProvider;

  ForeColor := BGRABlack;
  BackColor := BGRA(0,0,255);
  FNormalPenWidth := 5;
  FEraserWidth := 10;
  ToolEraserMode := emEraseAlpha;
  ShapeOptions := [toDrawShape, toFillShape, toCloseShape];
  ToolTolerance := 64;
  BlackAndWhite := ABlackAndWhite;

  ToolBrushSpacing := 1;
  ReloadBrushes;

  GradientType := gtLinear;
  GradientSine := false;
  GradientColorspace := ciLinearRGB;
  ToolFloodFillOptionProgressive := true;
  LineCap := pecRound;
  JoinStyle := pjsRound;
  ArrowStart := akNone;
  ArrowEnd := akNone;
  ArrowSize := PointF(2,2);
  PenStyle := psSolid;
  ToolEraserAlpha := 255;
  SplineStyle := ssEasyBezier;
  FTextOutline := False;
  FTextOutlineWidth := 2;
  TextShadow := false;
  FTextFont := TFont.Create;
  FTextFont.Size := 10;
  FTextFont.Name := 'Arial';
  ToolTextAlign := taLeftJustify;
  TextPhong := False;
  TextShadowBlurRadius := 4;
  TextShadowOffset := Point(5,5);
  LightPosition := PointF(0,0);
  LightAltitude := 100;
  PhongShapeAltitude := 50;
  PhongShapeBorderSize := 20;
  PhongShapeKind := pskRectangle;
  ToolPerspectiveRepeat := false;
  ToolPerspectiveTwoPlanes := false;
  FTextureOpactiy:= 255;
  FTexture := nil;
  FTextureAfterAlpha := nil;

  FDeformationGridNbX := 5;
  FDeformationGridNbY := 5;
  ToolDeformationGridMoveWithoutDeformation := false;

  PenWidthControls := TList.Create;
  AliasingControls := TList.Create;
  ShapeControls := TList.Create;
  PenStyleControls := TList.Create;
  CloseShapeControls := TList.Create;
  LineCapControls := TList.Create;
  JoinStyleControls := TList.Create;
  SplineStyleControls := TList.Create;
  EraserControls := TList.Create;
  ToleranceControls := TList.Create;
  GradientControls := TList.Create;
  DeformationControls := TList.Create;
  TextControls := TList.Create;
  TextShadowControls := TList.Create;
  PhongControls := TList.Create;
  AltitudeControls := TList.Create;
  PerspectiveControls := TList.Create;
  PenColorControls := TList.Create;
  TextureControls := TList.Create;
  BrushControls := TList.Create;
  RatioControls := TList.Create;

  FCurrentToolType := ptHand;
  FCurrentTool := PaintTools[ptHand].Create(Self);
end;

destructor TToolManager.Destroy;
var
  i: Integer;
begin
  SaveBrushes;
  CurrentTool.Free;

  PenWidthControls.Free;
  AliasingControls.Free;
  ShapeControls.Free;
  PenStyleControls.Free;
  CloseShapeControls.Free;
  LineCapControls.Free;
  JoinStyleControls.Free;
  SplineStyleControls.Free;
  EraserControls.Free;
  ToleranceControls.Free;
  GradientControls.Free;
  DeformationControls.Free;
  TextControls.Free;
  TextShadowControls.Free;
  PhongControls.Free;
  AltitudeControls.Free;
  PerspectiveControls.Free;
  PenColorControls.Free;
  TextureControls.Free;
  BrushControls.Free;
  RatioControls.Free;

  for i := 0 to BrushCount do
    BrushAt[i].Free;
  FBrushInfoList.Free;

  FTexture.FreeReference;
  FTexture := nil;
  FTextureAfterAlpha.Free;
  FTextFont.Free;
  inherited Destroy;
end;

procedure TToolManager.LoadFromConfig;
var
  Config: TLazPaintConfig;
  opt: TShapeOptions;
begin
  if Assigned(FConfigProvider) then
    Config := FConfigProvider.GetConfig
  else
    exit;
  ForeColor := Config.DefaultToolForeColor;
  BackColor := Config.DefaultToolBackColor;
  FNormalPenWidth := Config.DefaultToolPenWidth;
  FEraserWidth := Config.DefaultToolEraserWidth;
  opt := [];
  if Config.DefaultToolOptionDrawShape then include(opt, toDrawShape);
  if Config.DefaultToolOptionFillShape then include(opt, toFillShape);
  if Config.DefaultToolOptionCloseShape then include(opt, toCloseShape);
  ToolTolerance := Config.DefaultToolTolerance;
  TextShadow := Config.DefaultToolTextShadow;
  FTextOutline := Config.DefaultToolTextOutline;
  FTextOutlineWidth := Config.DefaultToolTextOutlineWidth;
  TextPhong := Config.DefaultToolTextPhong;
  with Config.DefaultToolTextFont do
    SetTextFont(Name, Size, Style);
  TextShadowBlurRadius := Config.DefaultToolTextBlur;
  TextShadowOffset := Config.DefaultToolTextShadowOffset;
  LightPosition := Config.DefaultToolLightPosition;
  LightAltitude := Config.DefaultToolLightAltitude;
  PhongShapeAltitude := Config.DefaultToolShapeAltitude;
  PhongShapeBorderSize := Config.DefaultToolShapeBorderSize;
  PhongShapeKind := Config.DefaultToolShapeType;
  ReloadBrushes;
end;

procedure TToolManager.SaveToConfig;
var
  Config: TLazPaintConfig;
begin
  if Assigned(FConfigProvider) then
    Config := FConfigProvider.GetConfig
  else
    exit;
  Config.SetDefaultToolForeColor(ForeColor);
  Config.SetDefaultToolBackColor(BackColor);
  Config.SetDefaultToolPenWidth(FNormalPenWidth);
  Config.SetDefaultToolEraserWidth(FEraserWidth);
  Config.SetDefaultToolOptionDrawShape(toDrawShape in ShapeOptions);
  Config.SetDefaultToolOptionFillShape(toFillShape in ShapeOptions);
  Config.SetDefaultToolOptionCloseShape(toCloseShape in ShapeOptions);
  Config.SetDefaultToolTolerance(ToolTolerance);

  Config.SetDefaultToolTextFont(FTextFont);
  Config.SetDefaultToolTextShadow(TextShadow);
  Config.SetDefaultToolTextOutline(TextOutline);
  Config.SetDefaultToolTextOutlineWidth(TextOutlineWidth);
  Config.SetDefaultToolTextBlur(TextShadowBlurRadius);
  Config.SetDefaultToolTextShadowOffset(TextShadowOffset);
  Config.SetDefaultToolTextPhong(TextPhong);

  Config.SetDefaultToolLightPosition(LightPosition);
  Config.SetDefaultToolLightAltitude(LightAltitude);
  Config.SetDefaultToolShapeBorderSize(PhongShapeBorderSize);
  Config.SetDefaultToolShapeAltitude(PhongShapeAltitude);
  Config.SetDefaultToolShapeType(PhongShapeKind);
end;

procedure TToolManager.ReloadBrushes;
var
  i: Integer;
  bi: TLazPaintBrush;
begin
  If Assigned(FBrushInfoList) then
  begin
    for i := 0 to FBrushInfoList.Count-1 do
      TObject(FBrushInfoList[i]).Free;
    FBrushInfoList.Clear;
  end else
    FBrushInfoList := TList.Create;
  if Assigned(FConfigProvider) and (FConfigProvider.GetConfig <> nil) then
  begin
    for i := 0 to FConfigProvider.GetConfig.BrushCount-1 do
    begin
      bi := TLazPaintBrush.Create;
      try
        bi.AsString := FConfigProvider.GetConfig.BrushInfo[i];
      except
        continue;
      end;
      FBrushInfoList.Add(bi);
    end;
  end;
  if FBrushInfoList.Count = 0 then
  begin
    FBrushInfoList.Add(TLazPaintBrush.Create(0,True));
    FBrushInfoList.Add(TLazPaintBrush.CreateFromStream64('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'));
  end;
  FBrushInfoListChanged := false;
end;

procedure TToolManager.SaveBrushes;
var
  i: Integer;
  infos: TStringList;
begin
  if Assigned(FConfigProvider) and FBrushInfoListChanged then
  begin
    infos := TStringList.Create;
    try
      for i := 0 to BrushCount-1 do
        infos.Add(BrushAt[i].AsString);
      FConfigProvider.GetConfig.SetBrushes(infos);
    except
    end;
    infos.Free;
  end;
  FBrushInfoListChanged := false;
end;

function TToolManager.ApplyPressure(AColor: TBGRAPixel): TBGRAPixel;
var alpha: integer;
begin
  alpha := round(AColor.alpha*ToolPressure);
  if alpha <= 0 then
    result := BGRAPixelTransparent
  else if alpha >= 255 then
    result := AColor
  else
  begin
    result := AColor;
    result.alpha := alpha;
  end;
end;

procedure TToolManager.SetPressure(APressure: single);
begin
  if APressure <= 0 then
    ToolPressure := 0
  else if APressure >= 1 then
    ToolPressure := 1
  else
    ToolPressure:= APressure;
end;

procedure TToolManager.InternalSetCurrentToolType(tool: TPaintToolType);
begin
  if (tool <> FCurrentToolType) or (FCurrentTool=nil) then
  begin
    FreeAndNil(FCurrentTool);
    if PaintTools[tool] <> nil then
      FCurrentTool := PaintTools[tool].Create(self)
    else
      FCurrentTool := nil;

    FCurrentToolType:= tool;
  end;

  if not IsSelectingTool then
    Image.ReleaseEmptySelection;

  Image.RenderMayChange(rect(0,0,Image.Width,Image.Height),True);

  UpdateContextualToolbars;

  FShouldExitTool:= false;
end;

procedure TToolManager.UpdateContextualToolbars;
var
  contextualToolbars: TContextualToolbars;
begin
  if Assigned(FCurrentTool) then
    contextualToolbars := FCurrentTool.GetContextualToolbars
  else
    contextualToolbars := [ctColor,ctTexture];

  SetControlsVisible(PenColorControls, ctColor in contextualToolbars);
  SetControlsVisible(TextureControls, ctTexture in contextualToolbars);
  SetControlsVisible(BrushControls, ctBrush in contextualToolbars);
  SetControlsVisible(ShapeControls, ctShape in contextualToolbars);
  SetControlsVisible(PenWidthControls, (ctPenWidth in contextualToolbars) and (toDrawShape in ShapeOptions));
  SetControlsVisible(JoinStyleControls, (ctJoinStyle in contextualToolbars) and (toDrawShape in ShapeOptions));
  SetControlsVisible(PenStyleControls, (ctPenStyle in contextualToolbars) and (toDrawShape in ShapeOptions));
  SetControlsVisible(CloseShapeControls, ctLineCap in contextualToolbars);
  SetControlsVisible(LineCapControls, (ctLineCap in contextualToolbars) and not (toCloseShape in ShapeOptions) and (toDrawShape in ShapeOptions));
  SetControlsVisible(AliasingControls, ctAliasing in contextualToolbars);
  SetControlsVisible(SplineStyleControls, ctSplineStyle in contextualToolbars);
  SetControlsVisible(EraserControls, ctEraserOption in contextualToolbars);
  SetControlsVisible(ToleranceControls, ctTolerance in contextualToolbars);
  SetControlsVisible(GradientControls, ctGradient in contextualToolbars);
  SetControlsVisible(DeformationControls, ctDeformation in contextualToolbars);
  SetControlsVisible(TextControls, ctText in contextualToolbars);
  SetControlsVisible(TextShadowControls, ctTextShadow in contextualToolbars);
  SetControlsVisible(PhongControls, ctPhong in contextualToolbars);
  SetControlsVisible(AltitudeControls, ctAltitude in contextualToolbars);
  SetControlsVisible(PerspectiveControls, ctPerspective in contextualToolbars);
  SetControlsVisible(RatioControls, ctRatio in contextualToolbars);

  If Assigned(FOnToolChangedHandler) then
    FOnToolChangedHandler(self, FCurrentToolType);
end;

function TToolManager.InternalBitmapToVirtualScreen(PtF: TPointF): TPointF;
begin
  if Assigned(FCurrentTool) then
  begin
    ptF.x += FCurrentTool.LayerOffset.X;
    ptF.y += FCurrentTool.LayerOffset.Y;
  end;
  result := BitmapToVirtualScreen(ptF);
end;

function TToolManager.AddLayerOffset(ARect: TRect): TRect;
begin
  result := ARect;
  if (result.Left = OnlyRenderChange.Left) and
    (result.Top = OnlyRenderChange.Top) and
    (result.Right = OnlyRenderChange.Right) and
    (result.Bottom = OnlyRenderChange.Bottom) then exit;
  if Assigned(FCurrentTool) then
    OffsetRect(result, FCurrentTool.LayerOffset.X,FCurrentTool.LayerOffset.Y);
end;

procedure TToolManager.ToolWakeUp;
begin
  if FSleepingTool <> nil then
  begin
    FreeAndNil(FCurrentTool);
    FCurrentTool := FSleepingTool;
    FSleepingTool := nil;
    FCurrentToolType := FSleepingToolType;
    InternalSetCurrentToolType(FCurrentToolType);
  end;
end;

procedure TToolManager.ToolSleep;
begin
  if (FSleepingTool = nil) and (FCurrentToolType <> ptHand) then
  begin
    FSleepingTool := FCurrentTool;
    FSleepingToolType := FCurrentToolType;
    FCurrentTool := nil;
    InternalSetCurrentToolType(ptHand);
  end;
end;

{ tool implementation }

function TToolManager.SetDeformationGridSize(NbX, NbY: integer): boolean;
begin
  result := false;
  if NbX < 3 then NbX := 3;
  if NbY < 3 then NbY := 3;
  if (NbX <> DeformationGridNbX) or (NbY <> DeformationGridNbY) then
  begin
    CurrentTool.BeforeGridSizeChange;
    FDeformationGridNbX := NbX;
    FDeformationGridNbY := NbY;
    CurrentTool.AfterGridSizeChange(NbX,NbY);
    result := true;
  end;
end;

procedure TToolManager.SwapToolColors;
var
  tmp: TBGRAPixel;
begin
  if (FForeColor.red = FBackColor.red) and
     (FForeColor.green = FBackColor.green) and
     (FForeColor.blue = FBackColor.blue) and
     (FForeColor.alpha = FBackColor.alpha) then exit;
  tmp := FForeColor;
  FForeColor := FBackColor;
  FBackColor := tmp;
  if Assigned(FOnColorChanged) then FOnColorChanged(self);
end;

procedure TToolManager.SetTexture(ATexture: TBGRABitmap);
begin
  SetTexture(ATexture, TextureOpacity);
end;

procedure TToolManager.SetTexture(ATexture: TBGRABitmap; AOpacity: byte);
begin
  if (ATexture = FTexture) and (AOpacity = FTextureOpactiy) then exit;
  if ATexture<>FTexture then
  begin
    FTexture.FreeReference;
    FTexture := ATexture.NewReference as TBGRABitmap;
  end;
  FTextureOpactiy:= AOpacity;
  FreeAndNil(FTextureAfterAlpha);
  if Assigned(FOnTextureChanged) then FOnTextureChanged(self);
end;

function TToolManager.GetTextureAfterAlpha: TBGRABitmap;
begin
  if (FTextureAfterAlpha = nil) and (FTexture <> nil) then
  begin
    FTextureAfterAlpha := FTexture.Duplicate as TBGRABitmap;
    FTextureAfterAlpha.ApplyGlobalOpacity(FTextureOpactiy);
  end;
  result := FTextureAfterAlpha;
end;

function TToolManager.GetTexture: TBGRABitmap;
begin
  result := FTexture;
end;

function TToolManager.BorrowTexture: TBGRABitmap;
begin
  result := FTexture;
  FTexture := nil;
  FreeAndNil(FTextureAfterAlpha);
  if Assigned(FOnTextureChanged) then FOnTextureChanged(self);
end;

procedure TToolManager.AddBrush(brush: TLazPaintBrush);
begin
  ToolBrushInfoIndex := FBrushInfoList.Add(brush);
  FBrushInfoListChanged := true;
end;

procedure TToolManager.RemoveBrushAt(index: integer);
begin
  if Assigned(FBrushInfoList) then
  begin
    if (index >= 1) and (index < BrushCount) then
    begin
      BrushAt[index].Free;
      FBrushInfoList.Delete(index);
      if index < ToolBrushInfoIndex then dec(ToolBrushInfoIndex)
      else if index = ToolBrushInfoIndex then
        begin
          if ToolBrushInfoIndex >= BrushCount then
            dec(ToolBrushInfoIndex);
        end;
      FBrushInfoListChanged := true;
    end;
  end;
end;

procedure TToolManager.SetTextFont(AName: string; ASize: integer;
  AStyle: TFontStyles);
begin
  if (FTextFont.Name <> AName) or
    (FTextFont.Size <> ASize) or
    (FTextFont.Style <> AStyle) then
  begin
    FTextFont.Name := AName;
    FTextFont.Size := ASize;
    FTextFont.Style := AStyle;
    if Assigned(FOnTextFontChanged) then FOnTextFontChanged(self);
  end;
end;

procedure TToolManager.SetTextFont(AFont: TFont);
begin
  SetTextFont(AFont.Name, AFont.Size, AFont.Style);
end;

function TToolManager.GetTextFont: TFont;
begin
  result := FTextFont;
end;

procedure TToolManager.SetTextOutline(AEnabled: boolean; AWidth: single);
begin
  if (FTextOutline <> AEnabled) or
    (FTextOutlineWidth <> AWidth) then
  begin
    FTextOutlineWidth := AWidth;
    FTextOutline := AEnabled;
    if Assigned(FOnTextOutlineChanged) then FOnTextOutlineChanged(self);
  end;
end;

function TToolManager.ToolDown(X, Y: single; ARightBtn: boolean;
  APressure: single): boolean;
var changed: TRect;
begin
  SetPressure(APressure);
  if ToolCanBeUsed then
    changed := currentTool.ToolDown(X,Y,ARightBtn)
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

function TToolManager.ToolMove(X, Y: single; APressure: single): boolean;
var changed: TRect;
begin
  SetPressure(APressure);
  if ToolCanBeUsed then
    changed := currentTool.ToolMove(X,Y)
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

procedure TToolManager.ToolMoveAfter(X, Y: single); overload;
begin
  if ToolCanBeUsed then
    currentTool.ToolMoveAfter(X,Y);
end;

function TToolManager.ToolKeyDown(var key: Word): boolean;
var changed: TRect;
begin
  if ToolCanBeUsed then
    changed := currentTool.ToolKeyDown(key)
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

function TToolManager.ToolKeyUp(var key: Word): boolean;
var changed: TRect;
begin
  if ToolCanBeUsed then
    changed := currentTool.ToolKeyUp(key)
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

function TToolManager.ToolKeyPress(var key: TUTF8Char): boolean;
var changed: TRect;
begin
  if ToolCanBeUsed then
    changed := currentTool.ToolKeyPress(key)
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

function TToolManager.ToolCommand(ACommand: TToolCommand): boolean;
begin
  if Assigned(FCurrentTool) then
    result := FCurrentTool.ToolCommand(ACommand)
  else
    result := false;
end;

function TToolManager.ToolProvideCommand(ACommand: TToolCommand): boolean;
begin
  if Assigned(FCurrentTool) then
    result := FCurrentTool.ToolProvideCommand(ACommand)
  else
    result := false;
end;

function TToolManager.ToolUp: boolean;
var changed: TRect;
begin
  if ToolCanBeUsed then
    changed := currentTool.ToolUp
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(currentTool.LastToolDrawingLayer, changed);
end;

procedure TToolManager.ToolCloseDontReopen;
begin
  if CurrentTool <> nil then
    FreeAndNil(FCurrentTool);
end;

procedure TToolManager.ToolCloseAndReopenImmediatly;
begin
  if CurrentTool <> nil then
  begin
    FreeAndNil(FCurrentTool);
    ToolOpen;
  end;
end;

procedure TToolManager.ToolOpen;
begin
  if (FCurrentTool = nil) and (PaintTools[FCurrentToolType] <> nil) then
    FCurrentTool := PaintTools[FCurrentToolType].Create(self);
end;

function TToolManager.ToolUpdate: boolean;
var changed: TRect;
begin
  if ToolCanBeUsed then
    changed := currentTool.ToolUpdate
  else
    changed := EmptyRect;
  result := not IsRectEmpty(changed);
  if IsOnlyRenderChange(changed) then changed := EmptyRect;

  if CheckExitTool then result := true;
  if result then NotifyImageOrSelectionChanged(CurrentTool.LastToolDrawingLayer, changed);
end;

function TToolManager.ToolUpdateNeeded: boolean;
begin
  if ToolCanBeUsed then
    result := currentTool.ToolUpdateNeeded
  else
    result := false;
  if CheckExitTool then
    result := true;
end;

procedure TToolManager.ToolPopup(AMessage: TToolPopupMessage);
begin
  if Assigned(FOnPopupToolHandler) then
    FOnPopupToolHandler(self, AMessage);
end;

function TToolManager.IsSelectingTool: boolean;
begin
  if CurrentTool <> nil then
    result := currentTool.IsSelectingTool
  else
    result := false;
end;

function TToolManager.DisplayFilledSelection: boolean;
begin
  result := IsSelectingTool or (FCurrentToolType = ptEditShape);
end;

procedure TToolManager.QueryExitTool;
begin
  FShouldExitTool:= true;
end;

procedure TToolManager.RenderTool(formBitmap: TBGRABitmap);
begin
  if ToolCanBeUsed then
    Image.RenderMayChange(currentTool.Render(formBitmap,formBitmap.Width,formBitmap.Height, @InternalBitmapToVirtualScreen));
end;

function TToolManager.GetRenderBounds(VirtualScreenWidth, VirtualScreenHeight: integer): TRect;
begin
  if ToolCanBeUsed and not currentTool.Validating and not currentTool.Canceling then
    result := currentTool.Render(nil,VirtualScreenWidth,VirtualScreenHeight, @InternalBitmapToVirtualScreen)
  else
    result := EmptyRect;
end;

function TToolManager.ToolDown(ACoord: TPointF; ARightBtn: boolean;
  APressure: single): boolean;
begin
  result := ToolDown(ACoord.x,ACoord.y,ARightBtn,APressure)
end;

function TToolManager.ToolMove(ACoord: TPointF; APressure: single): boolean;
begin
  result := ToolMove(ACoord.x,ACoord.y,APressure)
end;

procedure TToolManager.ToolMoveAfter(coord: TPointF); overload;
begin
  ToolMoveAfter(coord.x,coord.y);
end;

initialization
  fillchar({%H-}PaintTools,sizeof(PaintTools),0);

end.

