local _, ns = ...

-- Missing a word? Just say the key out loud!
local L = setmetatable({}, {
	__index = function(t, k)
		local v = tostring(k)
		rawset(t, k, v)
		return v
	end
})
ns.L = L

-- Supported locales: enUS, enGB, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ptPT, ruRU, zhCN, zhTW
local lang = GetLocale()

-- Do you speak English?
if lang == "enUS" or lang == "enGB" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: drag to move, right-click to lock"
	L["Sample roll: nothing was rolled."] = "Sample roll: nothing was rolled."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Showing sample roll bars. Type /lb test again to hide them."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} won {item}"
	L["Roll result unavailable"] = "Roll result unavailable"
	L["Roll details are no longer available."] = "Roll details are no longer available."
	L["Roll Bars"] = "Roll Bars"
	L["Enable roll bars"] = "Enable roll bars"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."
	L["Scale"] = "Scale"
	L["Size of the roll bars."] = "Size of the roll bars."
	L["Stack direction"] = "Stack direction"
	L["Which way new roll bars stack from the anchor."] = "Which way new roll bars stack from the anchor."
	L["Up"] = "Up"
	L["Down"] = "Down"
	L["Move bars"] = "Move bars"
	L["Move"] = "Move"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."
	L["Chat"] = "Chat"
	L["Enable roll summaries"] = "Enable roll summaries"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."
	L["Output window"] = "Output window"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."
	L["Automatic"] = "Automatic"
	return
end

-- Sprechen Sie Deutsch?
if lang == "deDE" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: Ziehen zum Verschieben, Rechtsklick zum Fixieren"
	L["Sample roll: nothing was rolled."] = "Beispielwurf: Es wurde nicht gewürfelt."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Beispiel-Wurfleisten werden angezeigt. Gib erneut /lb test ein, um sie auszublenden."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} gewinnt {item}"
	L["Roll result unavailable"] = "Würfelergebnis nicht verfügbar"
	L["Roll details are no longer available."] = "Die Würfeldetails sind nicht mehr verfügbar."
	L["Roll Bars"] = "Wurfleisten"
	L["Enable roll bars"] = "Wurfleisten aktivieren"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Ersetzt Blizzards Beutewurf-Fenster durch kompakte Leisten. Jede Schaltfläche zeigt, wie viele Spieler sie gewählt haben; zeige auf eine Schaltfläche, um zu sehen, wer."
	L["Scale"] = "Skalierung"
	L["Size of the roll bars."] = "Größe der Wurfleisten."
	L["Stack direction"] = "Stapelrichtung"
	L["Which way new roll bars stack from the anchor."] = "In welche Richtung neue Wurfleisten vom Anker aus gestapelt werden."
	L["Up"] = "Nach oben"
	L["Down"] = "Nach unten"
	L["Move bars"] = "Leisten verschieben"
	L["Move"] = "Verschieben"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Zeigt den Anker und Beispielleisten, damit du sie an die gewünschte Stelle ziehen kannst. Rechtsklick auf den Anker fixiert ihn."
	L["Chat"] = "Chat"
	L["Enable roll summaries"] = "Wurfzusammenfassungen aktivieren"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Blendet die einzelnen Wurfnachrichten im Chat aus und gibt pro Gegenstand eine Zeile mit dem Gewinner aus. Klicke auf die Zeile, um alle Würfe zu sehen."
	L["Output window"] = "Ausgabefenster"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"Das Chatfenster, in dem die Wurfzusammenfassungen erscheinen. Automatisch verwendet das erste Fenster, das Beutenachrichten anzeigt."
	L["Automatic"] = "Automatisch"
	return
end

-- ¿Hablas español?
if lang == "esES" or lang == "esMX" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: arrastra para mover, clic derecho para bloquear"
	L["Sample roll: nothing was rolled."] = "Tirada de ejemplo: no se ha tirado nada."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Mostrando barras de tirada de ejemplo. Escribe /lb test otra vez para ocultarlas."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} ha ganado {item}"
	L["Roll result unavailable"] = "Resultado de la tirada no disponible"
	L["Roll details are no longer available."] = "Los detalles de la tirada ya no están disponibles."
	L["Roll Bars"] = "Barras de tirada"
	L["Enable roll bars"] = "Activar barras de tirada"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Sustituye las ventanas de tirada de botín de Blizzard por barras compactas. Cada botón muestra cuántos jugadores lo han elegido; pasa el ratón por un botón para ver quiénes."
	L["Scale"] = "Escala"
	L["Size of the roll bars."] = "Tamaño de las barras de tirada."
	L["Stack direction"] = "Dirección de apilado"
	L["Which way new roll bars stack from the anchor."] = "Hacia dónde se apilan las nuevas barras de tirada desde el ancla."
	L["Up"] = "Arriba"
	L["Down"] = "Abajo"
	L["Move bars"] = "Mover barras"
	L["Move"] = "Mover"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Muestra el ancla y barras de ejemplo para que puedas arrastrarlas a su sitio. Haz clic derecho en el ancla para bloquearla."
	L["Chat"] = "Chat"
	L["Enable roll summaries"] = "Activar resúmenes de tiradas"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Oculta los mensajes de tirada de cada jugador en el chat y muestra una línea por objeto con el ganador. Haz clic en la línea para ver todas las tiradas."
	L["Output window"] = "Ventana de salida"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"La ventana de chat donde se muestran los resúmenes de tiradas. Automático usa la primera ventana que muestra mensajes de botín."
	L["Automatic"] = "Automático"
	return
end

-- Parlez-vous français ?
if lang == "frFR" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon : glisser pour déplacer, clic droit pour verrouiller"
	L["Sample roll: nothing was rolled."] = "Jet d'exemple : aucun jet n'a été effectué."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Affichage des barres de jet d'exemple. Tapez de nouveau /lb test pour les masquer."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} a gagné {item}"
	L["Roll result unavailable"] = "Résultat du jet indisponible"
	L["Roll details are no longer available."] = "Les détails du jet ne sont plus disponibles."
	L["Roll Bars"] = "Barres de jet"
	L["Enable roll bars"] = "Activer les barres de jet"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Remplace les fenêtres de jet de butin de Blizzard par des barres compactes. Chaque bouton indique combien de joueurs l'ont choisi ; survolez un bouton pour voir qui."
	L["Scale"] = "Échelle"
	L["Size of the roll bars."] = "Taille des barres de jet."
	L["Stack direction"] = "Sens d'empilement"
	L["Which way new roll bars stack from the anchor."] = "Dans quel sens les nouvelles barres de jet s'empilent à partir de l'ancre."
	L["Up"] = "Vers le haut"
	L["Down"] = "Vers le bas"
	L["Move bars"] = "Déplacer les barres"
	L["Move"] = "Déplacer"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Affiche l'ancre et des barres d'exemple pour que vous puissiez les placer. Faites un clic droit sur l'ancre pour la verrouiller."
	L["Chat"] = "Discussion"
	L["Enable roll summaries"] = "Activer les résumés de jets"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Masque les messages de jet de chaque joueur dans la discussion et affiche une ligne par objet indiquant le gagnant. Cliquez sur la ligne pour voir tous les jets."
	L["Output window"] = "Fenêtre de sortie"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"La fenêtre de discussion où s'affichent les résumés de jets. Automatique utilise la première fenêtre qui affiche les messages de butin."
	L["Automatic"] = "Automatique"
	return
end

-- Parli italiano?
if lang == "itIT" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: trascina per spostare, clic destro per bloccare"
	L["Sample roll: nothing was rolled."] = "Tiro di esempio: non è stato tirato nulla."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Barre di tiro di esempio visibili. Digita di nuovo /lb test per nasconderle."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} ha vinto {item}"
	L["Roll result unavailable"] = "Risultato del tiro non disponibile"
	L["Roll details are no longer available."] = "I dettagli del tiro non sono più disponibili."
	L["Roll Bars"] = "Barre di tiro"
	L["Enable roll bars"] = "Attiva le barre di tiro"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Sostituisce le finestre di tiro del bottino di Blizzard con barre compatte. Ogni pulsante mostra quanti giocatori l'hanno scelto; passa il mouse su un pulsante per vedere chi."
	L["Scale"] = "Scala"
	L["Size of the roll bars."] = "Dimensione delle barre di tiro."
	L["Stack direction"] = "Direzione di impilamento"
	L["Which way new roll bars stack from the anchor."] = "In quale direzione si impilano le nuove barre di tiro a partire dall'ancora."
	L["Up"] = "Verso l'alto"
	L["Down"] = "Verso il basso"
	L["Move bars"] = "Sposta barre"
	L["Move"] = "Sposta"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Mostra l'ancora e barre di esempio per trascinarle nella posizione voluta. Clic destro sull'ancora per bloccarla."
	L["Chat"] = "Chat"
	L["Enable roll summaries"] = "Attiva i riepiloghi dei tiri"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Nasconde in chat i messaggi di tiro dei singoli giocatori e mostra una riga per oggetto con il vincitore. Clicca sulla riga per vedere tutti i tiri."
	L["Output window"] = "Finestra di output"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"La finestra di chat in cui vengono mostrati i riepiloghi dei tiri. Automatico usa la prima finestra che mostra i messaggi del bottino."
	L["Automatic"] = "Automatico"
	return
end

-- 한국어 하세요?
if lang == "koKR" then
	L["BoP"] = "귀속"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: 끌어서 이동, 오른쪽 클릭으로 고정"
	L["Sample roll: nothing was rolled."] = "예시 주사위: 실제로 굴리지 않았습니다."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "예시 주사위 바를 표시합니다. 숨기려면 /lb test를 다시 입력하세요."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name}님이 {item} 획득"
	L["Roll result unavailable"] = "주사위 결과를 알 수 없음"
	L["Roll details are no longer available."] = "주사위 상세 정보를 더 이상 확인할 수 없습니다."
	L["Roll Bars"] = "주사위 바"
	L["Enable roll bars"] = "주사위 바 사용"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"블리자드의 전리품 주사위 창을 작은 바로 대체합니다. 각 버튼에 선택한 플레이어 수가 표시되며, 버튼에 마우스를 올리면 누가 선택했는지 볼 수 있습니다."
	L["Scale"] = "크기"
	L["Size of the roll bars."] = "주사위 바의 크기입니다."
	L["Stack direction"] = "쌓는 방향"
	L["Which way new roll bars stack from the anchor."] = "새 주사위 바가 고정점에서 쌓이는 방향입니다."
	L["Up"] = "위로"
	L["Down"] = "아래로"
	L["Move bars"] = "바 이동"
	L["Move"] = "이동"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"고정점과 예시 바를 표시하여 원하는 위치로 끌 수 있습니다. 고정점을 오른쪽 클릭하면 고정됩니다."
	L["Chat"] = "대화"
	L["Enable roll summaries"] = "주사위 요약 사용"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"대화창에서 플레이어별 주사위 메시지를 숨기고 아이템마다 획득자를 보여 주는 한 줄을 출력합니다. 줄을 클릭하면 모든 주사위 결과를 볼 수 있습니다."
	L["Output window"] = "출력 창"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"주사위 요약을 출력할 대화창입니다. 자동은 전리품 메시지를 표시하는 첫 번째 창을 사용합니다."
	L["Automatic"] = "자동"
	return
end

-- Você fala português?
if lang == "ptBR" or lang == "ptPT" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: arraste para mover, clique direito para travar"
	L["Sample roll: nothing was rolled."] = "Rolagem de exemplo: nada foi rolado."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Mostrando barras de rolagem de exemplo. Digite /lb test novamente para ocultá-las."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} ganhou {item}"
	L["Roll result unavailable"] = "Resultado da rolagem indisponível"
	L["Roll details are no longer available."] = "Os detalhes da rolagem não estão mais disponíveis."
	L["Roll Bars"] = "Barras de rolagem"
	L["Enable roll bars"] = "Ativar barras de rolagem"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Substitui as janelas de rolagem de saque da Blizzard por barras compactas. Cada botão mostra quantos jogadores o escolheram; passe o mouse sobre um botão para ver quem."
	L["Scale"] = "Escala"
	L["Size of the roll bars."] = "Tamanho das barras de rolagem."
	L["Stack direction"] = "Direção de empilhamento"
	L["Which way new roll bars stack from the anchor."] = "Para que lado as novas barras de rolagem se empilham a partir da âncora."
	L["Up"] = "Para cima"
	L["Down"] = "Para baixo"
	L["Move bars"] = "Mover barras"
	L["Move"] = "Mover"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Mostra a âncora e barras de exemplo para você arrastá-las até o lugar. Clique com o botão direito na âncora para travá-la."
	L["Chat"] = "Bate-papo"
	L["Enable roll summaries"] = "Ativar resumos de rolagem"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Oculta no bate-papo as mensagens de rolagem de cada jogador e mostra uma linha por item com o vencedor. Clique na linha para ver todas as rolagens."
	L["Output window"] = "Janela de saída"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"A janela de bate-papo onde os resumos de rolagem aparecem. Automático usa a primeira janela que mostra mensagens de saque."
	L["Automatic"] = "Automático"
	return
end

-- Говорите по-русски?
if lang == "ruRU" then
	L["BoP"] = "BoP"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon: перетащите, чтобы переместить; ПКМ — закрепить"
	L["Sample roll: nothing was rolled."] = "Пример броска: ничего не разыграно."
	L["Showing sample roll bars. Type /lb test again to hide them."] = "Показаны примеры полос розыгрыша. Введите /lb test ещё раз, чтобы скрыть их."
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} выигрывает {item}"
	L["Roll result unavailable"] = "Результат розыгрыша недоступен"
	L["Roll details are no longer available."] = "Подробности розыгрыша больше недоступны."
	L["Roll Bars"] = "Полосы розыгрыша"
	L["Enable roll bars"] = "Включить полосы розыгрыша"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"Заменяет окна розыгрыша добычи Blizzard компактными полосами. На каждой кнопке видно, сколько игроков её выбрали; наведите курсор на кнопку, чтобы увидеть кто."
	L["Scale"] = "Масштаб"
	L["Size of the roll bars."] = "Размер полос розыгрыша."
	L["Stack direction"] = "Направление"
	L["Which way new roll bars stack from the anchor."] = "В какую сторону от якоря складываются новые полосы розыгрыша."
	L["Up"] = "Вверх"
	L["Down"] = "Вниз"
	L["Move bars"] = "Переместить полосы"
	L["Move"] = "Переместить"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"Показывает якорь и примеры полос, чтобы их можно было перетащить на место. ПКМ по якорю закрепляет его."
	L["Chat"] = "Чат"
	L["Enable roll summaries"] = "Включить итоги розыгрышей"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"Скрывает в чате сообщения о бросках каждого игрока и выводит одну строку на предмет с победителем. Нажмите на строку, чтобы увидеть все броски."
	L["Output window"] = "Окно вывода"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"Окно чата, в которое выводятся итоги розыгрышей. «Автоматически» — первое окно, где показываются сообщения о добыче."
	L["Automatic"] = "Автоматически"
	return
end

-- 你会说中文吗？
if lang == "zhCN" then
	L["BoP"] = "绑定"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon：拖动以移动，右键点击以锁定"
	L["Sample roll: nothing was rolled."] = "示例掷骰：并未实际掷骰。"
	L["Showing sample roll bars. Type /lb test again to hide them."] = "正在显示示例掷骰条。再次输入 /lb test 可将其隐藏。"
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} 赢得了 {item}"
	L["Roll result unavailable"] = "掷骰结果不可用"
	L["Roll details are no longer available."] = "掷骰详情已不可用。"
	L["Roll Bars"] = "掷骰条"
	L["Enable roll bars"] = "启用掷骰条"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"用紧凑的掷骰条替换暴雪的拾取掷骰窗口。每个按钮会显示选择它的玩家数量；将鼠标指向按钮即可查看是谁。"
	L["Scale"] = "缩放"
	L["Size of the roll bars."] = "掷骰条的大小。"
	L["Stack direction"] = "堆叠方向"
	L["Which way new roll bars stack from the anchor."] = "新的掷骰条从锚点开始堆叠的方向。"
	L["Up"] = "向上"
	L["Down"] = "向下"
	L["Move bars"] = "移动掷骰条"
	L["Move"] = "移动"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"显示锚点和示例掷骰条，以便将其拖动到合适位置。右键点击锚点即可锁定。"
	L["Chat"] = "聊天"
	L["Enable roll summaries"] = "启用掷骰摘要"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"在聊天中隐藏每位玩家的掷骰信息，并为每件物品输出一行获胜者信息。点击该行可查看所有人的掷骰。"
	L["Output window"] = "输出窗口"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"显示掷骰摘要的聊天窗口。“自动”会使用第一个显示拾取信息的窗口。"
	L["Automatic"] = "自动"
	return
end

-- 你會說中文嗎？
if lang == "zhTW" then
	L["BoP"] = "綁定"
	L["LootBeacon: drag to move, right-click to lock"] = "LootBeacon：拖曳以移動，右鍵點擊以鎖定"
	L["Sample roll: nothing was rolled."] = "範例擲骰：並未實際擲骰。"
	L["Showing sample roll bars. Type /lb test again to hide them."] = "正在顯示範例擲骰列。再次輸入 /lb test 即可隱藏。"
	L["{roll} - {value}"] = "{roll} - {value}"
	L["{tag} {name} won {item}"] = "{tag} {name} 贏得了 {item}"
	L["Roll result unavailable"] = "擲骰結果無法取得"
	L["Roll details are no longer available."] = "擲骰詳情已無法取得。"
	L["Roll Bars"] = "擲骰列"
	L["Enable roll bars"] = "啟用擲骰列"
	L["Replaces Blizzard's loot roll windows with compact bars. Each button shows how many players chose it; point at a button to see who."] =
	"以精簡的擲骰列取代暴雪的拾取擲骰視窗。每個按鈕會顯示選擇它的玩家人數；將滑鼠指向按鈕即可查看是誰。"
	L["Scale"] = "縮放"
	L["Size of the roll bars."] = "擲骰列的大小。"
	L["Stack direction"] = "堆疊方向"
	L["Which way new roll bars stack from the anchor."] = "新的擲骰列從錨點開始堆疊的方向。"
	L["Up"] = "向上"
	L["Down"] = "向下"
	L["Move bars"] = "移動擲骰列"
	L["Move"] = "移動"
	L["Shows the anchor and sample bars so you can drag them into place. Right-click the anchor to lock it."] =
	"顯示錨點與範例擲骰列，以便將其拖曳到合適位置。右鍵點擊錨點即可鎖定。"
	L["Chat"] = "聊天"
	L["Enable roll summaries"] = "啟用擲骰摘要"
	L["Hides the per-player roll messages in chat and prints one line per item showing who won. Click the line to see everyone's rolls."] =
	"在聊天中隱藏每位玩家的擲骰訊息，並為每件物品輸出一行獲勝者資訊。點擊該行可查看所有人的擲骰。"
	L["Output window"] = "輸出視窗"
	L["The chat window roll summaries are printed to. Automatic uses the first window that shows loot messages."] =
	"顯示擲骰摘要的聊天視窗。「自動」會使用第一個顯示拾取訊息的視窗。"
	L["Automatic"] = "自動"
	return
end
