' ================================================================================
' FIGURE 4: SEQUENCE DIAGRAM - AI MEAL LOGGING (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure4_SequenceMealLogging()
    Dim doc As Document
    Set doc = ActiveDocument
    
    With doc.PageSetup
        .PaperSize = wdPaperA4
        .TopMargin = 54
        .BottomMargin = 54
        .LeftMargin = 54
        .RightMargin = 54
    End With
    
    Application.ScreenUpdating = False
    
    Dim curRng As Range
    Set curRng = doc.Paragraphs.Last.Range
    
    Dim baseY As Single, i As Integer
    baseY = 60
    
    Dim cols(1 To 5) As Single
    cols(1) = 75   ' User
    cols(2) = 175  ' Flutter UI
    cols(3) = 280  ' FastAPI
    cols(4) = 385  ' Gemini
    cols(5) = 485  ' Supabase
    
    AddBox doc, curRng, cols(1) - 30, baseY, 60, 25, "User", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 8
    AddBox doc, curRng, cols(2) - 35, baseY, 70, 25, "Flutter UI", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 8
    AddBox doc, curRng, cols(3) - 35, baseY, 70, 25, "FastAPI", RGB(253, 244, 255), RGB(192, 38, 211), RGB(134, 25, 143), True, 8
    AddBox doc, curRng, cols(4) - 35, baseY, 70, 25, "Gemini Pool", RGB(254, 243, 199), RGB(217, 119, 6), RGB(146, 64, 14), True, 8
    AddBox doc, curRng, cols(5) - 35, baseY, 70, 25, "Supabase DB", RGB(224, 231, 255), RGB(67, 56, 202), RGB(49, 46, 129), True, 8

    For i = 1 To 5
        AddArrow doc, curRng, cols(i), baseY + 25, cols(i), baseY + 290, RGB(203, 213, 225), True
    Next i

    baseY = baseY + 45
    AddArrow doc, curRng, cols(1), baseY, cols(2), baseY, RGB(37, 99, 235)
    AddBox doc, curRng, 85, baseY - 12, 80, 12, "1: Type '2 Parathas'", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(3), baseY, RGB(5, 150, 105)
    AddBox doc, curRng, 185, baseY - 12, 85, 12, "2: POST /meals/search", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(3), baseY, cols(4), baseY, RGB(192, 38, 211)
    AddBox doc, curRng, 290, baseY - 12, 85, 12, "3: generate_content()", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(4), baseY, cols(3), baseY, RGB(217, 119, 6), True
    AddBox doc, curRng, 290, baseY - 12, 85, 12, "4: {cals:540, p:11.5g...}", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(3), baseY, cols(2), baseY, RGB(192, 38, 211), True
    AddBox doc, curRng, 185, baseY - 12, 85, 12, "5: 200 OK Macros", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(1), baseY, cols(2), baseY, RGB(37, 99, 235)
    AddBox doc, curRng, 85, baseY - 12, 80, 12, "6: Tap 'Log Meal'", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddBox doc, curRng, cols(2) - 45, baseY - 10, 90, 20, "Write to Local SQLite" & vbCrLf & "(is_synced=false)", RGB(254, 242, 242), RGB(220, 38, 38), RGB(153, 27, 27), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(5), baseY, RGB(67, 56, 202)
    AddBox doc, curRng, 240, baseY - 12, 170, 12, "7: Background SyncWorker pushes row", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(5), baseY, cols(2), baseY, RGB(67, 56, 202), True
    AddBox doc, curRng, 240, baseY - 12, 170, 12, "8: 201 Created -> SQLite is_synced=true", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    AddCaption doc, "Figure 4", "UML Sequence Diagram: AI Meal Logging and Macro Estimation Lifecycle."
    Application.ScreenUpdating = True
    MsgBox "Figure 4 Generated Successfully!", vbInformation, "NutriSense"
End Sub

Function AddBox(doc As Document, anchorRng As Range, leftPos As Single, topPos As Single, w As Single, h As Single, _
                txt As String, fillRGB As Long, borderRGB As Long, textRGB As Long, _
                Optional isBold As Boolean = False, Optional fSize As Single = 8.5, _
                Optional shapeType As MsoAutoShapeType = msoShapeRoundedRectangle) As Shape
    Dim shp As Shape
    Set shp = doc.Shapes.AddShape(shapeType, leftPos, topPos, w, h, Anchor:=anchorRng)
    With shp
        .RelativeHorizontalPosition = wdRelativeHorizontalPositionPage
        .RelativeVerticalPosition = wdRelativeVerticalPositionPage
        .Left = leftPos
        .Top = topPos
        .Fill.Solid
        .Fill.ForeColor.RGB = fillRGB
        .Line.ForeColor.RGB = borderRGB
        .Line.Weight = 1.2
        With .TextFrame
            .TextRange.Text = txt
            .TextRange.Font.Name = "Calibri"
            .TextRange.Font.Size = fSize
            .TextRange.Font.Color = textRGB
            .TextRange.Font.Bold = isBold
            .TextRange.ParagraphFormat.Alignment = wdAlignParagraphCenter
            .MarginLeft = 3
            .MarginRight = 3
            .MarginTop = 2
            .MarginBottom = 2
        End With
    End With
    Set AddBox = shp
End Function

Function AddArrow(doc As Document, anchorRng As Range, startX As Single, startY As Single, endX As Single, endY As Single, _
                  lineRGB As Long, Optional isDashed As Boolean = False) As Shape
    Dim shp As Shape
    Set shp = doc.Shapes.AddLine(startX, startY, endX, endY, Anchor:=anchorRng)
    With shp
        .RelativeHorizontalPosition = wdRelativeHorizontalPositionPage
        .RelativeVerticalPosition = wdRelativeVerticalPositionPage
        With .Line
            .ForeColor.RGB = lineRGB
            .Weight = 1.5
            .EndArrowheadStyle = msoArrowheadTriangle
            .EndArrowheadLength = msoArrowheadLengthMedium
            .EndArrowheadWidth = msoArrowheadWidthMedium
            If isDashed Then
                .DashStyle = msoLineDash
            End If
        End With
    End With
    Set AddArrow = shp
End Function

Sub AddCaption(doc As Document, figureTitle As String, desc As String)
    Dim p As Paragraph
    Set p = doc.Paragraphs.Add
    p.Range.Text = vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & _
                   vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & _
                   figureTitle & ": " & desc & vbCrLf
    p.Range.Font.Name = "Calibri"
    p.Range.Font.Size = 10
    p.Range.Font.Italic = True
    p.Range.Font.Color = RGB(51, 65, 85)
    p.Range.ParagraphFormat.Alignment = wdAlignParagraphCenter
End Sub
