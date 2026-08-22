' ================================================================================
' FIGURE 2: UML USE CASE DIAGRAM (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure2_UseCaseDiagram()
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
    
    ' Actors on Left & Right
    AddBox doc, curRng, 54, baseY + 70, 85, 45, "User:" & vbCrLf & "Primary User", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 8.5
    AddBox doc, curRng, 54, baseY + 200, 85, 45, "User:" & vbCrLf & "Family Member", RGB(253, 242, 248), RGB(219, 39, 119), RGB(157, 23, 77), True, 8.5
    
    AddBox doc, curRng, 455, baseY + 90, 85, 45, "Service:" & vbCrLf & "AI Clinical Coach", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 8.5
    AddBox doc, curRng, 455, baseY + 220, 85, 45, "Service:" & vbCrLf & "Clinic / OSM API", RGB(254, 242, 242), RGB(220, 38, 38), RGB(153, 27, 27), True, 8.5

    ' System Boundary
    AddBox doc, curRng, 155, baseY, 285, 335, "", RGB(248, 250, 252), RGB(100, 116, 139), RGB(15, 23, 42), True, 9.5
    AddBox doc, curRng, 165, baseY + 6, 265, 18, "NutriSense Healthcare System Boundary", RGB(226, 232, 240), RGB(100, 116, 139), RGB(15, 23, 42), True, 8.5

    ' Use Case Ovals
    Dim uc(1 To 9) As String
    uc(1) = "UC1: Log Meal with AI Auto-Macros"
    uc(2) = "UC2: Voice & Text Clinical Consultation"
    uc(3) = "UC3: Scan Barcode for Allergen Conflicts"
    uc(4) = "UC4: Track Ramadan Fasting & Hydration"
    uc(5) = "UC5: Manage Multi-Family Profiles"
    uc(6) = "UC6: Search Emergency Clinics & Hospitals"
    uc(7) = "UC7: Sync Google Health Connect Data"
    uc(8) = "UC8: Export Weekly Clinical PDF Report"
    uc(9) = "UC9: Offline Meal Logging & Auto-Sync"

    For i = 1 To 9
        AddBox doc, curRng, 175, baseY + 28 + (i - 1) * 33, 245, 26, uc(i), RGB(255, 255, 255), RGB(5, 150, 105), RGB(6, 95, 70), False, 7.5, msoShapeOval
    Next i

    ' Actor Associations
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 41, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 74, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 107, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 140, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 173, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 206, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 239, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 272, RGB(37, 99, 235)
    AddArrow doc, curRng, 139, baseY + 92, 175, baseY + 305, RGB(37, 99, 235)

    AddArrow doc, curRng, 139, baseY + 222, 175, baseY + 41, RGB(219, 39, 119)
    AddArrow doc, curRng, 139, baseY + 222, 175, baseY + 173, RGB(219, 39, 119)

    AddArrow doc, curRng, 420, baseY + 41, 455, baseY + 112, RGB(5, 150, 105)
    AddArrow doc, curRng, 420, baseY + 74, 455, baseY + 112, RGB(5, 150, 105)
    AddArrow doc, curRng, 420, baseY + 107, 455, baseY + 112, RGB(5, 150, 105)
    AddArrow doc, curRng, 420, baseY + 206, 455, baseY + 242, RGB(220, 38, 38)

    AddCaption doc, "Figure 2", "UML Use Case Diagram showing actors and functional core capabilities."
    Application.ScreenUpdating = True
    MsgBox "Figure 2 Generated Successfully!", vbInformation, "NutriSense"
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
