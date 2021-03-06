\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2012/02/09 evalsheets]

\RequirePackage{fix-cm}
\LoadClass[twoside,7pt]{scrartcl}
\RequirePackage{fixltx2e}

\RequirePackage[T1]{fontenc}
\RequirePackage{amssymb}
\RequirePackage{array}
\RequirePackage{babel}
\RequirePackage{bophook}
\RequirePackage{forloop}
\RequirePackage{calc}
\RequirePackage{color}
\RequirePackage{colortbl}
\RequirePackage{geometry}
\RequirePackage{graphicx}
\RequirePackage{ifthen}
\RequirePackage{multirow}
\let\amssymbBox\Box
\RequirePackage{MnSymbol}
\let\Box\amssymbBox
\RequirePackage{tabularx}
\RequirePackage{tgheros}
\RequirePackage[breakall]{truncate}
\RequirePackage{xparse}
\RequirePackage{xstring}
\RequirePackage[pdf]{pstricks}

\RequirePackage{pst-barcode}
\renewcommand{\rmdefault}{\sfdefault}

% centered, fixed width table column
\newcolumntype{C}[1]{>{\centering\arraybackslash}p{#1}}

% backup hline command. hline will be disabled when a new section begins in order to avoid several
% rules. hlineback is used to restore hline functionality after each question.
\let\hlineback\hline

% Variable used to store further answers until they can be printed into the question table. See
% \moreAnswers for a explanation on how to use this.
\def\hasMoreAnswers{}

% choice counter, used to increment each answer box by one. Reset at the start of \quest
\newcounter{choiceCounter}
% answer counter, used to count the # of answers. Currently used to be able to print out the
% db field for multiple choice questions correctly and to be able to identify which of the boxes
% is the last one. Reset at the end of \quest.
\newcounter{answerCounter}
% same thing, but for rows. Currently unused, but stays because it might be useful.
\newcounter{rowCounter}

\setcounter{section}{0}

\newcommand{\resetQuestionCounters}{%
  \setcounter{answerCounter}{0}%
  \setcounter{rowCounter}{2}%
}
\resetQuestionCounters

% a normal question fits only two lines of text. If a third one is needed the question will over-
% flow into whatever comes next. This is because the multirow package does not increase the
% tabular's height, even if required by the contents inside the multirow. Therefore we use this
% variable to measure the question's height and add some \vspace if required.
\newlength\questionHeight
% in case one of the answers overflow, calculate the additional width required
\newlength\sectionHeight
% used for calcing table height
\newlength\tmpa
\newlength\tmpb
% used to store size of comment field
\newlength\commentSize
% used to store the size of the last-checkbox-as-textbox
\newlength\lastBoxSize

% shorthand to write information into posout file. If you wonder about the leading 'u's: it's not
% possible to write leading spaces or #-signs using TeX. The latexfix.rb script replaces those
% 'u's with two spaces each, i.e. 'uuu' will result in '      ' in the final file. Only u, uu and
% uuu are supported. In addition, 'U' serves as comment character for the YAML file, i.e. it will
% be replaced with '#' if and only if it's the first character on that line (including spaces).
\def\wPosout{\write\posout}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for-each-page stuff (e.g. headers, edges)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\geometry{left=9mm,right=9mm, top=0.5cm, bottom=1.1cm}

% print edges and repeated header (if available) for each page
\AtBeginPage{
  \put(15, -15){\rule{1cm}{1pt}}
  \put(15, -43){\rule{1pt}{1cm}}
  %\put(15, -830){\rule{1cm}{1pt}}
  %\put(15, -830){\rule{1pt}{1cm}}
  \put(554, -15){\rule{1cm}{1pt}}
  \put(581.5, -43){\rule{1pt}{1cm}}
  \put(554, -830){\rule{1cm}{1pt}}
  \put(581.5, -830){\rule{1pt}{1cm}}%put datamatrix in left lower corner
  \put(15,-830){\begin{pspicture}(0,0)(1cm,1cm)
  	\psbarcode{\storedLectureID-\storedSheetID-\thepage}{format=rectangle version=12x36 height=0.24}{datamatrix}
  	\end{pspicture}}
  \wPosout{- !ruby/object:Page}
  \wPosout{u questions:}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% some style options
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\DeclareOption*{%
\PassOptionsToClass{\CurrentOption}{scrartcl}%
}
\ProcessOptions\relax

\renewcommand{\TruncateMarker}{\textasciitilde}

\pagestyle{empty}

\renewcommand{\baselinestretch}{1}
\setlength\tabcolsep{0pt}

\setlength\parindent{0pt}

\definecolor{gray}{rgb}{.88,.88,.88}
\definecolor{darkgray}{rgb}{.6,.6,.6}

% overwrite color of the horizontal lines
\arrayrulecolor{darkgray}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% common functions to write out data, headers, checkboxes, ...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% these two print out how boxes should be checked and/or corrected. Boxes are sized and aligned to
% be used in vanilla text
\newcommand{\checkLikeThis}{{\LARGE \raisebox{-0.1mm}{$\medsquare$\kern0em$\boxtimes$\kern0em$\medsquare$\kern0em$\medsquare$}}}
\newcommand{\correctLikeThis}{{\LARGE \raisebox{-0.1mm}{$\medsquare$\kern0em$\filledmedsquare$\kern0em$\medsquare$\kern0em$\boxtimes$}}}


% let the user store data using these commands
\newcommand{\lecture}[1]{\def\storedLecture{#1}}
\newcommand{\lectureID}[1]{\def\storedLectureID{#1}}
\newcommand{\sheetID}[1]{\def\storedSheetID{#1}}
\newcommand{\vorlesung}[1]{\message{DEPRECATION: The command "vorlesung" is deprecated. Please use "lecture" instead. Arguments are exactly the same.}\def\storedLecture{#1}}
\newcommand{\term}[1]{\def\storedTerm{#1}}
\newcommand{\semester}[1]{\message{DEPRECATION: The command "semester" is deprecated. Please use "term" instead. Arguments are exactly the same.}\def\storedTerm{#1}}
\newcommand{\dbtable}[1]{\def\dbt{#1}}
\newcommand{\tutoren}[1]{\message{DEPRECATION: The command "tutoren" is deprecated. Please use "tutors" instead. Arguments are exactly the same.}\def\tut{#1}}
\newcommand{\tutors}[1]{\def\tut{#1}}
\newcommand{\noAnswerText}[1]{\def\noAnswTxt{#1}}
\newcommand{\lecturerLast}[1]{\def\lectLast{#1}}
\newcommand{\lecturerFirst}[1]{\def\lectFirst{#1}}
% for simplicity
\newcommand{\lect}{\lectFirst{} \lectLast{}}
% The name of the tutor is not available when printing the forms. However, it is in result.pdf
% Therefore you can use these placeholders in the form to later fill in the real name in
% result.pdf. Note that gender is never available for tutors. If the name is not available \tutor
% contains e.g. "tutor" or "Tutor/in" and \myTutor "My Tutor" or "Meine Tutor/in". If the name is
% available, both contain the name and only the name (i.e. tutor.abbrv_name).
\newcommand{\setTutor}[1]{\def\tutor{#1}}
\newcommand{\setMyTutor}[1]{\def\myTutor{#1}}

% set output file
\newwrite\posout
\openout\posout\jobname.posout
\newwrite\postwo
\openout\postwo\jobname.two.posout
\def\Source{}

% saves the current coordinates into the YAML file as x and y variables
\def\SavePos{
  \pdfsavepos
	\wPosout{uuu x: \number\pdflastxpos}
	\wPosout{uuu y: \number\pdflastypos}
}

% saves the current coordinates into the YAML file as width and height. Note that width and height
% are confusing since actual coordinates are saved.
\def\SavePosAsWH{
  \pdfsavepos
	\wPosout{uuu width: \number\pdflastxpos}
	\wPosout{uuu height: \number\pdflastypos}
}

\def\tutorbox[#1][#2]{%
  \wPosout{uuu choice: "#1"}
  \vspace{-0.3cm}
  \truncate{3cm}{#2}
}

% draws a checkbox and stores its position into the posout. Note that if you change this, ensure
% the correction values in seee/pest/omr2.rb's function search_square_box are still valid. The
% command currently gives the coordinates at the box's lower right corner.
% Does not save any choice attribute. Currently only used to print the tutor table.
\def\bx{{\huge$\Box$}\SavePos}

\newboolean{lastBox}
% prints a box and stores its position in the posout file along with the given value. If no value
% is given the global choiceCounter is incremented and its value is printed into the posout file
%  instead.
\newcommand{\bxs}[1][]{%
  \vspace{-0.8em}
  \wPosout{uu- !ruby/object:Box}
  % no argument given, so auto-count
  \IfStrEq{#1}{}{
    \stepcounter{choiceCounter}
    \edef\saveText{uuu choice: "\arabic{choiceCounter}"}
    \wPosout\expandafter{\saveText}
    % is this the last checkbox?
    \IfStrEq{\arabic{choiceCounter}}{\arabic{answerCounter}}
      {\setboolean{lastBox}{true}}
      {\setboolean{lastBox}{false}}
  }{\wPosout{uuu choice: "#1"}\setboolean{lastBox}{false}}
  \hspace{0.5em}
  \ifthenelse{\boolean{lastIsTextbox}}{% check for last box
    \ifthenelse{\boolean{lastBox}}{% make it a textbox... sort of
      \vspace*{-1mm} % don't kill that newline

      \wPosout{uuu width: \number\lastBoxSize}
      % 15mm is the amount of space that fits any column. Ideally the
      % box would auto-size to the space available, but this is not
      % possible yet.
      \begin{minipage}{\lastBoxSize}%
        \hspace*{\lastBoxSize}%
        \llap{\smash{\framebox[\lastBoxSize]{\vbox to 1.2mm{}}}}%
        \SavePos%
      \end{minipage}
      \vspace*{-5mm}
    }{ % not the last checkbox, so simply print a normal box
      \bx
    }
  }{ % all checkboxes are normal, no need for fancy stuff
    \bx
  }
}

\def\SaveLastIsTextBoxInfo{%
  % Note: the actual value is not required anymore, as long as all
  % following scripts handle that last textbox a little differently.
  \ifthenelse{\boolean{lastIsTextbox}}{\wPosout{uu last_is_textbox: 123456}}{}
}

% writes the posout information for multiple choice questions give the database prefix
% as first option and the amount of boxes as second.
% The letters (a, b, c, ..., (noansw)) will be added automatically
\newcounter{multiCounter}
\def\SaveMultiInfo[#1][#2]{%
  \wPosout{u - !ruby/object:Question}
  \SaveLastIsTextBoxInfo
  \wPosout{uu type: square}
  \wPosout{uu db_column: }
  \setcounter{multiCounter}{0}
  \whiledo{\value{multiCounter} < #2}{
    \stepcounter{multiCounter}
    \edef\saveText{uu - #1\alph{multiCounter}}
    \wPosout\expandafter{\saveText}
  }
  \ifthenelse{\boolean{noanswer}}{\wPosout{uu - #1noansw}}{}
  \wPosout{uu boxes:}
}

% writes the posout information for single choice questions
\def\SaveNormalInfo[#1]{%
  \wPosout{u - !ruby/object:Question}
  \SaveLastIsTextBoxInfo
  \wPosout{uu type: square}
  \wPosout{uu db_column: #1}
  \wPosout{uu boxes:}
}

% automatically chooses between SaveNormalInfo and SaveMultiInfo depending on
% how \boolean{single} is set. First argument needs to be the db_column.
\def\SaveInfo[#1]{%
  % the save commands use space for some reason, therefore the \makebox command
  \ifthenelse{\boolean{single}}{%
    \makebox[0mm]{\SaveNormalInfo[#1]}
  }{
    \makebox[0mm]{\SaveMultiInfo[#1][\arabic{answerCounter}]}
  }
  % fix the additional hspace that is introduced by above commands
  \hspace*{-4.9mm}
}

% places everything into a box as wide as the page, thus preventing its contents
% from being interrupted by a page break. Moves its content slightly to the left
% to combat the hardcoded padding inside the box. Usage:
% \preventBreak{%
%    some content
% }
\newcommand{\preventBreak}[1]{
  \begin{tabular}[t]{p{192mm}}
    #1
  \end{tabular}
  \vspace*{-1.8mm}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% header related stuff
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prints main caption and barcode
\newcommand{\head}[2]{
  \wPosout{--- !ruby/object:AbstractForm}
  \wPosout{db_table: \dbt}
  \wPosout{pages: }
  \wPosout{- !ruby/object:Page }
  \wPosout{u questions: }
  \def\storedLectureID{#2}
  \vspace*{-1.85mm}
  \Huge{#1}\normalsize
  \hfill\raisebox{-2.1mm}{\begin{pspicture}(3cm,1cm)
  	\psbarcode{#2}{ height=0.30 width=1.1811}{ean8}
  	\end{pspicture}}\\
  \vspace*{-2mm}
}

% prints data that identifies what/who is being evaluated
\newcommand{\dataline}[3]{
  \textbf{#1:} \storedLecture \hfill\textbf{#2:} \lect \hfill\textbf{#3:} \storedTerm \\[0.2em]
}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% sections
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% helper function that prints the main text in a header
\newcommand{\sectText}[1]{\ \ \textbf{#1} \phantom{\"Ay}}
% helper function prints the gray box around any content given in the style of a headline
\newcommand{\sectBox}[1]{\colorbox{gray}{%
  \hspace*{-1.05mm}%
  \parbox{192mm}{%
    #1%
    \vspace*{-1mm}%
  }%
  \hspace*{-1.8mm}
}}
% helper function that sets the given options in a tabular environment so everything aligns. See
% \sect for a better explanation.
\NewDocumentCommand\sectFullBox{m o o o o o o o}{%
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{
    \IfNoValueTF{#4}{
    \IfNoValueTF{#3}{
    \IfNoValueTF{#2}{
      \sectBox{\tabHeadOneAnsw   \sectText{#1} &          &          & \\[0.6mm]\hline \end{tabular}}
    }{\sectBox{\tabHeadOneAnsw   \sectText{#1} & \small#2 &          & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadTwoAnsw   \sectText{#1} & \small#2 & \small#3 & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadThreeAnsw \sectText{#1} & \small#2 & \small#3 & \small#4 & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadFourAnsw  \sectText{#1} & \small#2 & \small#3 & \small#4 & \small#5 & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadFiveAnsw  \sectText{#1} & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadSixAnsw   \sectText{#1} & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \small#7 & \\[0.6mm]\hline \end{tabular}}}
    }{\sectBox{\tabHeadSevenAnsw \sectText{#1} & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \small#7 & \small#8 & \\[0.6mm]\hline \end{tabular}}}
}

% prints out a new section header. First argument specifies the main bold text, following options are
% placed to match the checkboxes from the answers. For example, specifying
% \sect{header}[abc][][xyz]
% would result in a header with text "header" and the other options aligned to questions with 3 answers.
% "abc" would be centered above the 1st box, "xyz" above the 3rd (here: last) and the middle one would
% have no text above it in the header.
\NewDocumentCommand\sect{m o o o o o o o}{%
  \setlength{\sectionHeight}{\totalheightof{\sectFullBox{#1}[#2][#3][#4][#5][#6][#7][#8]} - 15.38791pt}
  \setlength{\sectionHeight}{\the\sectionHeight/2}
  \setlength{\sectionHeight}{\maxof{\the\sectionHeight}{0mm}}

  \stepcounter{section}
  \sectFullBox{\arabic{section}. #1}[#2][#3][#4][#5][#6][#7][#8]

  \vspace*{-2.4mm}
  \vspace*{\the\sectionHeight}
  \renewcommand{\hline}{}
}

\newcommand{\secte}{
  \vspace{-1.2em}\rule{192mm}{1.5pt}\vspace{0.5em}
}

% used at the end of the page to mark the end of a comment field
\newcommand{\separator}[1]{
  \vspace{-1.15em}\rule{19.2cm}{#1}\\
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Questions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\newboolean{single}
\newboolean{noanswer}
\newboolean{printAnswers}
\newboolean{lastIsTextbox}

% shorthand for the multirow command in each table. It only spans one row, which makes it look
% superflous. However, if removed the question text will expand the first row instead of spreading
% into the following rows, wasting valuable space. The correct amount of rows is available in
% \rowCounter, but even then multirow somehow gets it wrong and the question text is neither
% centered nor on top. Long story short, multirow enables the text to overflow; height issues are
% handled in \printTable.
\newcommand{\questText}[1]{
  \multirow{1}{7.7cm}{#1}
}

% prints the answer text for each box unless printAnswers has been disabled for this question
\newcommand{\aText}[1]{
  \ifthenelse{\boolean{printAnswers}}{\small#1}{}
}


% measures the height of the question's text and the height of the table and adds some vertical
% space if the text exceeds the table. This is due to multirow not extending the table as
% required, leading to overflows when the question text needs more space than the answers.
\newcommand{\printTable}[1]{
  % calc some basic heights. Also used by other functions that follow. raggedright somehow
  % influences where line breaks occur (some may fit in one line while others don’t),
  % therefore it’s important for the height calculation.
  \settototalheight{\tmpa}{\parbox{7.7cm}{\raggedright{}#1}}
  \settototalheight{\tmpb}{\tbl}
  % find height of (question text)-(table)+(magic value)
  \setlength{\questionHeight}{\tmpa-\tmpb+2.5mm}
  % measuring the table lays it out, thus increasing the choiceCounter even though it shouldn't be
  \setcounter{choiceCounter}{0}
  %some unused debug info to print into the document
  %\setlength{\tmpb}{\maxof{\the\tmpa}{\the\tmpb}}
  %\setlength{\tmpb}{\tmpb-5mm}
  %\smash{\fbox{\the\questionHeight\  \the\tmpa\  \the\tmpb}}
  % ensure only space is added for the question text to fit, but never removed. If the answers are
  % hidden, allow up to 3mm to be removed to account for the now empty table row.
  \ifthenelse{\boolean{printAnswers}}{
    \setlength{\questionHeight}{\maxof{\the\questionHeight}{0mm}}
  }{
    \setlength{\questionHeight}{\maxof{\the\questionHeight}{-3.3mm}}
  }
  % print the table
  \tbl
  \vspace*{\questionHeight}
  %\ifthenelse{\boolean{printAnswers}}{}{\vspace*{-3mm}}
}

% places a divider on the left of a given box and fills the height of the whole table, but does
% not touch the prev/next \hline.
\def\divider{%
  % find whichever needs more space
  \setlength{\tmpa}{\maxof{\tmpa}{\tmpb}}%
  % leave a little whitespace around the rule, thus subtract a little bit and also take missing
  % answers into account
  \addtolength{\tmpa}{-1mm+\questionHeight}%
  % if there are \moreAnswers, simply assume they are evenly divided. This is not perfect but has
  % to suffice, until a better method is found that can directly measure the height of the first
  % and second row only.
  \setlength{\tmpa}{\tmpa*2/\arabic{rowCounter}}%
  % 2.8mm is the amount of space from the baseline of the "\Box"-row to the preceeding \hline.
  % In other words, moving the rule down its own height places its top (vertically) at the center
  % of each checkbox. The 2.8mm are used to move it up, so it aligns nicely with the \hline above.
  \setlength{\tmpb}{-\tmpa+2.8mm}%
  % smash the rule so that the box doesn't appear out of place if the divider is there. The
  % vspaces are required because \smash (and not the rule!) add some space for some reason which
  % makes TeX break pages earlier than without smash. So, the vspaces prevent spurious page
  % breaks while not affecting anything else at all. Way to go TeX!
  \vspace*{-0.2mm}\smash{\hspace*{-0.5mm}\rule[\tmpb]{\arrayrulewidth}{\the\tmpa}}\vspace*{-0.2mm}%
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper commands that print each of the tables depending on how many answers are required.

\def\tabHeadOneAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}@{\hspace*{73.84mm}}p{0mm}}}
\def\tabHeadTwoAnsw{\tabHeadOneAnsw}
%\def\tabHeadThreeAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}@{\hspace*{58.09mm}}C{15.75mm}p{0mm}}} % aligned with the 6-answ question
\def\tabHeadThreeAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{7.85mm}}C{31.4mm}@{\hspace*{39.25mm}}C{15.75mm}p{0mm}}} % aligned with the 4-answ question
\def\tabHeadFourAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{7.85mm}}C{31.4mm}C{31.4mm}@{\hspace*{7.85mm}}C{15.75mm}p{0cm}}}
\def\tabHeadFiveAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{3.925mm}}C{23.55mm}C{23.55mm}C{23.55mm}@{\hspace*{3.925mm}}C{15.75mm}p{0mm}}}
\def\tabHeadSixAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}C{18.84mm}C{18.84mm}C{18.84mm}@{\hspace*{1.57mm}}C{15.75mm}p{0mm}}}
\def\tabHeadSevenAnsw{\begin{tabular}[t]{p{8.2cm}C{15.75mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.75mm}p{0mm}}}

% very small helper that adds the hline on top of each question and also writes the questions's
% header to the posout file.
% Note that the question header info needs to be saved from within the table, otherwise it might
% be split during a page break, resulting in broken posout files.
\def\tabSubHeader[#1]{
  \hline\\[-0.8em]
  \SaveInfo[#1]
}

%%%% these questions automatically add the "no answer" box to the end %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% the arguments are the same for all questions, they are:
% db_column, question text, answer text 1, answer text 2, ...

% 2 answers, is aligned to the 5-answers question
\newcommand{\tabNoAnswTwo}[4]{
  \def\tbl{\tabHeadThreeAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \divider \bxs[99]     &\\
                    & \aText{#3}  & \aText{#4}  & \aText{\noAnswTxt}    &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 3 answers + no answer, i.e. 47.1mm more space, thus 15.7mm additional space between boxes
\newcommand{\tabNoAnswThree}[5]{
  \def\tbl{\tabHeadFourAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \bxs        & \divider \bxs[99]     &\\
                    & \aText{#3}  & \aText{#4}  & \aText{#5}  & \aText{\noAnswTxt}    &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 4 answers + no answer, i.e. 31.4mm more space, thus 7.85mm additional space between boxes
\newcommand{\tabNoAnswFour}[6]{
  \def\tbl{\tabHeadFiveAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs      & \bxs        & \bxs        & \bxs        & \divider \bxs[99]     &\\
                    & \aText{#3}& \aText{#4}  & \aText{#5}  & \aText{#6}  & \aText{\noAnswTxt}    &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 5 answers + no answer, i.e. 15.7mm more space, thus 3.14mm additional space between boxes
\newcommand{\tabNoAnswFive}[7]{
  \def\tbl{\tabHeadSixAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs      & \bxs        & \bxs        & \bxs        & \bxs        & \divider \bxs[99]     &\\
                    & \aText{#3}& \aText{#4}  & \aText{#5}  & \aText{#6}  & \aText{#7}  & \aText{\noAnswTxt}    &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 6 answers + no answer
\newcommand{\tabNoAnswSix}[8]{
  \def\tbl{\tabHeadSevenAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \bxs        &  \bxs        & \bxs        & \bxs        & \divider \bxs[99]     &\\
                    & \aText{#3}  & \aText{#4}  & \aText{#5}  & \aText{#6}   & \aText{#7}  & \aText{#8}  & \aText{\noAnswTxt}    &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

%%%% these questions do not add a "no answer" box to the end %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1 answer
\newcommand{\tabOne}[3]{
  \def\tbl{\tabHeadOneAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        &      &   \\
                    & \aText{#3}  &      &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 2 answers, is aligned to the 5-answers question
\newcommand{\tabTwo}[4]{
  \def\tbl{\tabHeadTwoAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        &   \\
                    & \aText{#3}  & \aText{#4}  &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 3 answers
\newcommand{\tabThree}[5]{
  \def\tbl{\tabHeadThreeAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \bxs        &  \\
                    & \aText{#3}  & \aText{#4}  & \aText{#5}  &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 4 answers
\newcommand{\tabFour}[6]{
  \def\tbl{\tabHeadFourAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \bxs        & \bxs        & \\
                    & \aText{#3}  & \aText{#4}  & \aText{#5}  & \aText{#6}  &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 5 answers
\newcommand{\tabFive}[7]{
  \def\tbl{\tabHeadFiveAnsw
    \tabSubHeader[#1]
    \questText{#2}   & \bxs        & \bxs        & \bxs        & \bxs        & \bxs        & \\
                     & \aText{#3}  & \aText{#4}  & \aText{#5}  & \aText{#6}  & \aText{#7}  &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 6 answers
\newcommand{\tabSix}[8]{
  \def\tbl{\tabHeadSixAnsw
    \tabSubHeader[#1]
    \questText{#2}   & \bxs       & \bxs        & \bxs        & \bxs         & \bxs        &  \bxs        & \\
                     & \aText{#3} & \aText{#4}  & \aText{#5}  & \aText{#6}   & \aText{#7}  &  \aText{#8}  &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}

% 7 answers
\newcommand{\tabSeven}[9]{
  \def\tbl{\tabHeadSevenAnsw
    \tabSubHeader[#1]
    \questText{#2}  & \bxs        & \bxs        & \bxs        & \bxs         & \bxs        & \bxs        & \bxs           &\\
                    & \aText{#3}  & \aText{#4}  & \aText{#5}  & \aText{#6}   & \aText{#7}  & \aText{#8}  & \aText{#9}     &
    \hasMoreAnswers
  \end{tabular}}
  \printTable{#2}
}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% allows up to six possible answers. Arguments are as follows:
% \quest
% <(single|multi) (noanswer)> All arguments are optional. noanswer will add a now answer box to
%  (printAnswers|hideAnswers) at the end. Single/multi make the question single/multi choice.
%                             Use hideAnswers if you want to print them in a special header. This
%                             is useful if you have a large block that share the same answers.
%                             hideAnswers and \moreAnswers are incompatible and will likely lead
%                             to space issues (combining them makes no sense anyway)
%
% {db_table_column_name}      multiple choice question get the names: namea, nameb, namec, and so
%                             on. If the question also has a noanswer box it will be named namenoansw
% {question text}
% [first answer]
% [second answer]
% ...
\NewDocumentCommand\quest{D<>{} m m o o o o o o}{%
  % set defaults
  \setboolean{single}{true}
  \setboolean{noanswer}{true}
  \setboolean{lastIsTextbox}{false}
  \setboolean{printAnswers}{true}
  \setcounter{choiceCounter}{0}

  \IfSubStr{#1}{single}{\setboolean{single}{true}}{}
  \IfSubStr{#1}{multi}{\setboolean{single}{false}}{}
  \IfSubStr{#1}{noanswer}{\setboolean{noanswer}{true}}{\setboolean{noanswer}{false}}
  \IfSubStr{#1}{printAnswers}{\setboolean{printAnswers}{true}}{}
  \IfSubStr{#1}{hideAnswers}{\setboolean{printAnswers}{false}}{}
  \IfSubStr{#1}{lastIsTextbox}{\setboolean{lastIsTextbox}{true}}{}

  % move question closer to the previous one
  %\vspace*{-3.5mm}

  % count answers
  \IfNoValueTF{#9}{
  \IfNoValueTF{#8}{
  \IfNoValueTF{#7}{
  \IfNoValueTF{#6}{
  \IfNoValueTF{#5}{
    \addtocounter{answerCounter}{1}
  }{\addtocounter{answerCounter}{2}}
  }{\addtocounter{answerCounter}{3}}
  }{\addtocounter{answerCounter}{4}}
  }{\addtocounter{answerCounter}{5}}
  }{\addtocounter{answerCounter}{6}}

  % without this the questions will be written out after *all* begin-of-page hooks. I.e. you'd
  % have a couple of "- !ruby/object:Page" at the start of the posout followed by all questions
  % regardless which page they were on. This writing ensures TeX writes bop-hook, questions,
  % bop-hook, questions and so on. No idea why this is required.
  \wPosout{U wtf?-fix (see eval.cls) ||| #3}

  % Print the question, depending on how many answers are given
  \ifthenelse{\boolean{noanswer}}{ % "no answer" checkbox is added automatically
    \IfNoValueTF{#9}{
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{% 1 answer
      \Huge{Wir sind doch nicht in der DDR hier!}\\
    }{\tabNoAnswTwo{#2}{#3}{#4}{#5}}
    }{\tabNoAnswThree{#2}{#3}{#4}{#5}{#6}}
    }{\tabNoAnswFour{#2}{#3}{#4}{#5}{#6}{#7}}
    }{\tabNoAnswFive{#2}{#3}{#4}{#5}{#6}{#7}{#8}}
    }{\tabNoAnswSix{#2}{#3}{#4}{#5}{#6}{#7}{#8}{#9}}
  }{ % "no answer" checkbox NOT included
    \IfNoValueTF{#9}{
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{% 1 answer
      \Huge{Wir sind doch nicht in der DDR hier!}\\
    }{\tabTwo{#2}{#3}{#4}{#5}}
    }{\tabThree{#2}{#3}{#4}{#5}{#6}}
    }{\tabFour{#2}{#3}{#4}{#5}{#6}{#7}}
    }{\tabFive{#2}{#3}{#4}{#5}{#6}{#7}{#8}}
    }{\tabSix{#2}{#3}{#4}{#5}{#6}{#7}{#8}{#9}}
  }%
  % end lines with %-signs, because otherwise there will be too much space between questions
  % enable hline for the following questions
  \global\let\hline\hlineback%
  % reset answers for following question.
  \global\def\hasMoreAnswers{}%
  % reset answer and row counter for next question
  \resetQuestionCounters
} % end of command quest


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% allows up to seven possible answers directly *before* a \quest. It is not suitable to be used on
% its own. The alignment is determined by \quest, so you cannot have a different raster for each
% line.
% Currently only supports single choice questions.
% \moreAnswers
% {first answer}
% {second answer}
% ...
\NewDocumentCommand\moreAnswers{o o o o o o o}{%
  \addtocounter{rowCounter}{2}%
  \IfNoValueTF{#7}{
  \IfNoValueTF{#6}{
  \IfNoValueTF{#5}{
  \IfNoValueTF{#4}{
  \IfNoValueTF{#3}{
  \IfNoValueTF{#2}{
    \addtocounter{answerCounter}{1}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     &
      \\      & \small#1}
  }{\addtocounter{answerCounter}{2}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     & \bxs     &
      \\      & \small#1 & \small#2}
  }}{\addtocounter{answerCounter}{3}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3}
  }}{\addtocounter{answerCounter}{4}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs    & \bxs     & \bxs     & \bxs     &
      \\      &\small#1 & \small#2 & \small#3 & \small#4}
  }}{\addtocounter{answerCounter}{5}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5}
  }}{\addtocounter{answerCounter}{6}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5 & \small#6}
  }}{\addtocounter{answerCounter}{7}
    \g@addto@macro\hasMoreAnswers{
      \\[4mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \small#7}
  }
}

% prints tutors (requires them to have been set before). Expects first argument to be the
% question text and 2nd argument the db_column to store the result to.
\newcommand{\printtutors}[2]{
  \vspace*{-1.4mm}
  \preventBreak{
    \SaveNormalInfo[#2]%
    \separator{\arrayrulewidth}%
    \vspace{-3.4mm}%
    #1\\[1.1mm]
    \hspace*{-0.3mm}\begin{tabular}{@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}}
      \tut
    \end{tabular}
    \vspace*{1.7mm}
  }
}

% comment field. Usage:
% \comment<HEIGHT>{QUESTION}{SAVE_AS_POSTFIX_AND_DB_COLUMN}
\NewDocumentCommand\comment{D<>{278} m m}{%
  \vspace{-1.45mm}
  % once with and once without units for the PDF output and posout file
  \setlength{\commentSize}{10000sp*#1}
  \preventBreak{
    % print the question text just for the sake of debugging
    \wPosout{U ||| #2}
    \wPosout{u - !ruby/object:Question}
    \wPosout{uu choice: }
    \wPosout{uu db_column: "#3"}
    \wPosout{uu type: text}
    \wPosout{uu boxes:}%
    \separator{0.9\arrayrulewidth}%
    \vspace{-3.4mm}%
    #2

    \wPosout{uu- !ruby/object:Box}%
    \wPosout{U absolute values; made before the comment box starts}%
    \SavePos%

    \fbox{\vbox to \commentSize {\vfil
    \wPosout{U absolute values(!) (grep this: WIDTH_HEIGHT_AS_COORDINATE); made from within the box}%
    \vfil
    \hbox to 189.7mm{\hfill\SavePosAsWH}%
    }}
    % keep this newline or otherwise the following pdf positions will be moved up for some
    % reason

  }
}

% makes the following page act as comment field
\newcommand{\backpagecomment}[1]{
  \newpage
  \mbox{}
  \wPosout{u - !ruby/object:Question}
  \wPosout{uu type: text_wholepage}
  \wPosout{uu db_column: "#1"}
  \let\lastSectionHeadReal\undefined
}
