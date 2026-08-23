' ================================================================================
' FIGURE 5: SEQUENCE DIAGRAM - GEMINI FAILOVER (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure5_SequenceKeyFailover()
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
    cols(1) = 75   ' Backend App
    cols(2) = 175  ' GeminiPool
    cols(3) = 280  ' Key #1
    cols(4) = 385  ' Key #2
    cols(5) = 485  ' Key #3
    
    AddBox doc, curRng, cols(1) - 30, baseY, 60, 25, "Backend App", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 8
    AddBox doc, curRng, cols(2) - 35, baseY, 70, 25, "GeminiPool", RGB(253, 244, 255), RGB(192, 38, 211), RGB(134, 25, 143), True, 8
    AddBox doc, curRng, cols(3) - 30, baseY, 60, 25, "Gemini Key 1", RGB(254, 242, 242), RGB(220, 38, 38), RGB(153, 27, 27), True, 8
    AddBox doc, curRng, cols(4) - 30, baseY, 60, 25, "Gemini Key 2", RGB(254, 242, 242), RGB(220, 38, 38), RGB(153, 27, 27), True, 8
    AddBox doc, curRng, cols(5) - 30, baseY, 60, 25, "Gemini Key 3", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 8

    For i = 1 To 5
        AddArrow doc, curRng, cols(i), baseY + 25, cols(i), baseY + 250, RGB(203, 213, 225), True
    Next i

    baseY = baseY + 45
    AddArrow doc, curRng, cols(1), baseY, cols(2), baseY, RGB(37, 99, 235)
    AddBox doc, curRng, 85, baseY - 12, 80, 12, "1: generate_content()", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(3), baseY, RGB(192, 38, 211)
    AddBox doc, curRng, 185, baseY - 12, 85, 12, "2: Request with Key 1", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 25
    AddArrow doc, curRng, cols(3), baseY, cols(2), baseY, RGB(220, 38, 38), True
    AddBox doc, curRng, 185, baseY - 12, 85, 12, "3: 429 EXHAUSTED", RGB(255, 255, 255), RGB(255, 255, 255), RGB(220, 38, 38), True, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(4), baseY, RGB(192, 38, 211)
    AddBox doc, curRng, 210, baseY - 12, 140, 12, "4: Auto-Failover: Try Key 2", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 25
    AddArrow doc, curRng, cols(4), baseY, cols(2), baseY, RGB(220, 38, 38), True
    AddBox doc, curRng, 210, baseY - 12, 140, 12, "5: 429 EXHAUSTED", RGB(255, 255, 255), RGB(255, 255, 255), RGB(220, 38, 38), True, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(5), baseY, RGB(192, 38, 211)
    AddBox doc, curRng, 250, baseY - 12, 180, 12, "6: Auto-Failover: Try Key 3", RGB(255, 255, 255), RGB(255, 255, 255), RGB(15, 23, 42), False, 6.5

    baseY = baseY + 25
    AddArrow doc, curRng, cols(5), baseY, cols(2), baseY, RGB(5, 150, 105), True
    AddBox doc, curRng, 250, baseY - 12, 180, 12, "7: 200 OK Successful Inference", RGB(255, 255, 255), RGB(255, 255, 255), RGB(5, 150, 105), True, 6.5

    baseY = baseY + 30
    AddArrow doc, curRng, cols(2), baseY, cols(1), baseY, RGB(5, 150, 105), True
    AddBox doc, curRng, 85, baseY - 12, 80, 12, "8: Return JSON Payload", RGB(255, 255, 255), RGB(255, 255, 255), RGB(5, 150, 105), True, 6.5

    AddCaption doc, "Figure 5", "UML Sequence Diagram: Gemini Multi-Key Failover and High-Availability Rotation."
    Application.ScreenUpdating = True
    MsgBox "Figure 5 Generated Successfully!", vbInformation, "NutriSense"
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
