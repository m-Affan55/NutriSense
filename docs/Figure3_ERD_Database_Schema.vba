' ================================================================================
' FIGURE 3: ENTITY-RELATIONSHIP DIAGRAM (ERD) (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure3_ERD()
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
    
    ' Table 1: USERS
    AddBox doc, curRng, 54, baseY, 150, 90, "USERS" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ email: string" & vbCrLf & "+ created_at: timestamp" & vbCrLf & "+ last_sign_in: timestamp", _
           RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), False, 7.5

    ' Table 2: HEALTH_PROFILES
    AddBox doc, curRng, 222, baseY, 150, 110, "HEALTH_PROFILES" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ user_id: uuid (FK)" & vbCrLf & "+ age, gender, height" & vbCrLf & "+ weight, goal" & vbCrLf & "+ daily_calorie_target" & vbCrLf & "+ medical_conditions" & vbCrLf & "+ dietary_restrictions", _
           RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), False, 7.5

    ' Table 3: FAMILY_MEMBERS
    AddBox doc, curRng, 390, baseY, 150, 110, "FAMILY_MEMBERS" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ primary_user_id: FK" & vbCrLf & "+ name: string" & vbCrLf & "+ relationship: string" & vbCrLf & "+ age, calorie_target" & vbCrLf & "+ medical_conditions" & vbCrLf & "+ dietary_restrictions", _
           RGB(253, 242, 248), RGB(219, 39, 119), RGB(157, 23, 77), False, 7.5

    ' Relationships Top Row
    AddArrow doc, curRng, 204, baseY + 45, 222, baseY + 45, RGB(37, 99, 235)
    AddArrow doc, curRng, 372, baseY + 45, 390, baseY + 45, RGB(219, 39, 119)

    ' Table 4: MEAL_LOGS
    baseY = baseY + 130
    AddBox doc, curRng, 54, baseY, 150, 115, "MEAL_LOGS" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ user_id: uuid (FK)" & vbCrLf & "+ family_member_id: FK" & vbCrLf & "+ meal_type: string" & vbCrLf & "+ notes: text" & vbCrLf & "+ total_calories: int" & vbCrLf & "+ protein, carbs, fat" & vbCrLf & "+ is_synced: bool", _
           RGB(254, 243, 199), RGB(217, 119, 6), RGB(146, 64, 14), False, 7.5

    ' Table 5: WATER_LOGS
    AddBox doc, curRng, 222, baseY, 150, 80, "WATER_LOGS" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ user_id: uuid (FK)" & vbCrLf & "+ amount_ml: int" & vbCrLf & "+ logged_at: timestamp", _
           RGB(236, 254, 255), RGB(8, 145, 178), RGB(21, 94, 117), False, 7.5

    ' Table 6: CHAT_HISTORY
    AddBox doc, curRng, 390, baseY, 150, 80, "CHAT_HISTORY" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ user_id: uuid (FK)" & vbCrLf & "+ sender: string" & vbCrLf & "+ message: text" & vbCrLf & "+ metadata: jsonb", _
           RGB(245, 243, 255), RGB(124, 58, 237), RGB(91, 33, 182), False, 7.5

    ' Table 7: HABIT_SCORES
    baseY = baseY + 125
    AddBox doc, curRng, 222, baseY, 150, 75, "HABIT_SCORES" & vbCrLf & "-----------------------" & vbCrLf & _
           "+ id: uuid (PK)" & vbCrLf & "+ user_id: uuid (FK)" & vbCrLf & "+ current_score: float" & vbCrLf & "+ streak_days: int", _
           RGB(241, 245, 249), RGB(71, 85, 105), RGB(30, 41, 59), False, 7.5

    AddArrow doc, curRng, 129, 180, 129, 220, RGB(37, 99, 235)
    AddArrow doc, curRng, 297, 200, 297, 220, RGB(8, 145, 178)
    AddArrow doc, curRng, 465, 200, 465, 220, RGB(124, 58, 237)
    AddArrow doc, curRng, 297, 300, 297, 345, RGB(71, 85, 105)

    AddCaption doc, "Figure 3", "Entity-Relationship Diagram (ERD) of NutriSense Database Schema in Supabase PostgreSQL."
    Application.ScreenUpdating = True
    MsgBox "Figure 3 Generated Successfully!", vbInformation, "NutriSense"
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
