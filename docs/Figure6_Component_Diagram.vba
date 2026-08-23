' ================================================================================
' FIGURE 6: SOFTWARE COMPONENT DIAGRAM (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure6_ComponentDiagram()
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
    
    Dim baseY As Single
    baseY = 60
    
    ' Package 1: Client Layer
    AddBox doc, curRng, 54, baseY, 486, 75, "", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 9.5
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "Client Layer (Flutter Mobile & Web App)", RGB(219, 234, 254), RGB(37, 99, 235), RGB(30, 64, 175), True, 8.5
    AddBox doc, curRng, 64, baseY + 25, 72, 38, "UI Widgets &" & vbCrLf & "Design System", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 142, baseY + 25, 72, 38, "Navigation &" & vbCrLf & "Router Shell", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 220, baseY + 25, 74, 38, "Sync Engine &" & vbCrLf & "SQLite Cache", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 300, baseY + 25, 72, 38, "Flutter TTS" & vbCrLf & "Voice Engine", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 378, baseY + 25, 72, 38, "Health Connect" & vbCrLf & "Bridge", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 456, baseY + 25, 74, 38, "Ramadan Fast" & vbCrLf & "Controller", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 297, baseY + 75, 297, baseY + 95, RGB(37, 99, 235)

    ' Package 2: Backend Application Layer
    baseY = baseY + 95
    AddBox doc, curRng, 54, baseY, 486, 75, "", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 9.5
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "Application Layer (FastAPI Backend Microservices)", RGB(209, 250, 229), RGB(5, 150, 105), RGB(6, 95, 70), True, 8.5
    AddBox doc, curRng, 64, baseY + 25, 90, 38, "Meal & Macro" & vbCrLf & "Estimator", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 158, baseY + 25, 90, 38, "AI Clinical Coach" & vbCrLf & "Service", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 252, baseY + 25, 90, 38, "Heuristic Symptom" & vbCrLf & "Evaluator", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 346, baseY + 25, 90, 38, "Gemini Multi-Key" & vbCrLf & "Rotator Pool", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 440, baseY + 25, 90, 38, "ReportLab PDF" & vbCrLf & "Generator", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 297, baseY + 75, 297, baseY + 95, RGB(5, 150, 105)

    ' Package 3: Integration Layer
    baseY = baseY + 95
    AddBox doc, curRng, 54, baseY, 486, 65, "", RGB(253, 244, 255), RGB(192, 38, 211), RGB(134, 25, 143), True, 9.5
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "Integration Layer (Cloud Infrastructure & Third-Party APIs)", RGB(245, 208, 254), RGB(192, 38, 211), RGB(134, 25, 143), True, 8.5
    AddBox doc, curRng, 64, baseY + 24, 110, 30, "Google Gemini" & vbCrLf & "Cloud API", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 182, baseY + 24, 110, 30, "Supabase Database" & vbCrLf & "& Auth Gateway", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 300, baseY + 24, 110, 30, "Overpass OpenStreet" & vbCrLf & "Map API (Clinics)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 418, baseY + 24, 112, 30, "OpenFoodFacts" & vbCrLf & "Product Database", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5

    AddCaption doc, "Figure 6", "Software Component Diagram of Client, Backend Services, and External Cloud APIs."
    Application.ScreenUpdating = True
    MsgBox "Figure 6 Generated Successfully!", vbInformation, "NutriSense"
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
