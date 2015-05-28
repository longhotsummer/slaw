# encoding: UTF-8

require 'builder'

require 'slaw'

describe Slaw::ActGenerator do
  def parse(rule, s)
    subject.builder.text_to_syntax_tree(s, {root: rule})
  end

  def should_parse(rule, s)
    s << "\n" unless s.end_with?("\n")
    tree = subject.builder.text_to_syntax_tree(s, {root: rule})

    if not tree
      raise Exception.new(subject.failure_reason || "Couldn't match to grammar") if tree.nil?
    else
      # count an assertion
      tree.should_not be_nil
    end
  end

  def to_xml(node, *args)
    b = ::Nokogiri::XML::Builder.new
    node.to_xml(b, *args)
    b.doc.root.to_xml(encoding: 'UTF-8')
  end

  #-------------------------------------------------------------------------------
  # Chapters
  #
  describe 'chapters' do
    it 'should handle chapter headers' do
      node = parse :chapter, <<EOS
ChaPTEr 2
The Chapter Heading
1. Section
Hello there
EOS
      node.num.should == "2"
      node.heading.title.should == 'The Chapter Heading'
      to_xml(node).should == '<chapter id="chapter-2">
  <num>2</num>
  <heading>The Chapter Heading</heading>
  <section id="section-1">
    <num>1.</num>
    <heading>Section</heading>
    <subsection id="section-1.subsection-0">
      <content>
        <p>Hello there</p>
      </content>
    </subsection>
  </section>
</chapter>'
    end
  end

  #-------------------------------------------------------------------------------
  # Parts

  describe 'parts' do
    it 'should handle part headers' do
      node = parse :part, <<EOS
pART 2
The Part Heading
1. Section
Hello there
EOS
      node.num.should == "2"
      node.heading.title.should == 'The Part Heading'
      to_xml(node).should == '<part id="part-2">
  <num>2</num>
  <heading>The Part Heading</heading>
  <section id="section-1">
    <num>1.</num>
    <heading>Section</heading>
    <subsection id="section-1.subsection-0">
      <content>
        <p>Hello there</p>
      </content>
    </subsection>
  </section>
</part>'
    end

    it 'should handle part headers with dashes' do
      node = parse :part, <<EOS
Part 2 - The Part Heading
1. Section
Hello there
EOS
      node.num.should == "2"
      node.heading.title.should == 'The Part Heading'
      to_xml(node).should == '<part id="part-2">
  <num>2</num>
  <heading>The Part Heading</heading>
  <section id="section-1">
    <num>1.</num>
    <heading>Section</heading>
    <subsection id="section-1.subsection-0">
      <content>
        <p>Hello there</p>
      </content>
    </subsection>
  </section>
</part>'
    end

    it 'should handle part headers with colons' do
      node = parse :part, <<EOS
Part 2: The Part Heading
1. Section
Hello there
EOS
      node.num.should == "2"
      node.heading.title.should == 'The Part Heading'
      to_xml(node).should == '<part id="part-2">
  <num>2</num>
  <heading>The Part Heading</heading>
  <section id="section-1">
    <num>1.</num>
    <heading>Section</heading>
    <subsection id="section-1.subsection-0">
      <content>
        <p>Hello there</p>
      </content>
    </subsection>
  </section>
</part>'
    end

    it 'should handle parts and odd section numbers' do
      subject.parser.options = {section_number_after_title: false}
      node = parse :act, <<EOS
PART 1
PREVENTION AND SUPPRESSION OF HEALTH NUISANCES
1.
No owner or occupier of any shop or business premises or vacant land adjoining a shop or business premises shall cause a health nuisance.
EOS

      part = node.chapters.elements[0].parts.elements[0]
      part.heading.num.should == "1"
      part.heading.title.should == "PREVENTION AND SUPPRESSION OF HEALTH NUISANCES"

      section = part.elements[1].elements[0]
      section.section_title.title.should == ""
      section.section_title.section_title_prefix.number_letter.text_value.should == "1"
    end
  end

  #-------------------------------------------------------------------------------
  # Subsections

  describe 'subsection' do
    it 'should handle basic subsections' do
      should_parse :subsection, <<EOS
        (2) foo bar
EOS
    end

    it 'should handle a naked statement' do
      should_parse :subsection, 'naked statement'
    end

    it 'should handle a naked statement and blocklist' do
      node = parse :subsection, <<EOS
        naked statement (c) blah
        (a) foo
        (b) bar
EOS
      node.statement.clauses.text_value.should == "naked statement (c) blah"
      node.blocklist.elements.first.num.should == "(a)"
      to_xml(node, "").should == '<subsection id="subsection-0">
  <content>
    <blockList id="subsection-0.list0">
      <listIntroduction>naked statement (c) blah</listIntroduction>
      <item id="subsection-0.list0.a">
        <num>(a)</num>
        <p>foo</p>
      </item>
      <item id="subsection-0.list0.b">
        <num>(b)</num>
        <p>bar</p>
      </item>
    </blockList>
  </content>
</subsection>'
    end

    it 'should handle a blocklist' do
      node = parse :subsection, <<EOS
        (2) title
        (a) one
        (b) two
        (c) three
        (i) four
EOS
      node.statement.num.should == "(2)"
      node.statement.content.text_value.should == "title"
      to_xml(node, "").should == '<subsection id="2">
  <num>(2)</num>
  <content>
    <blockList id="2.list0">
      <listIntroduction>title</listIntroduction>
      <item id="2.list0.a">
        <num>(a)</num>
        <p>one</p>
      </item>
      <item id="2.list0.b">
        <num>(b)</num>
        <p>two</p>
      </item>
      <item id="2.list0.c">
        <num>(c)</num>
        <p>three</p>
      </item>
      <item id="2.list0.i">
        <num>(i)</num>
        <p>four</p>
      </item>
    </blockList>
  </content>
</subsection>'
    end

    it 'should handle a subsection that dives straight into a list' do
      node = parse(:subsection, <<EOS
        (1) (a) one
        (b) two
        (c) three
        (i) four
EOS
                  )
      node.statement.content.should be_nil
      node.blocklist.elements.first.num.should == "(a)"
      node.blocklist.elements.first.content.should == "one"
      to_xml(node, "").should == '<subsection id="1">
  <num>(1)</num>
  <content>
    <blockList id="1.list0">
      <item id="1.list0.a">
        <num>(a)</num>
        <p>one</p>
      </item>
      <item id="1.list0.b">
        <num>(b)</num>
        <p>two</p>
      </item>
      <item id="1.list0.c">
        <num>(c)</num>
        <p>three</p>
      </item>
      <item id="1.list0.i">
        <num>(i)</num>
        <p>four</p>
      </item>
    </blockList>
  </content>
</subsection>'
    end

    it 'should handle a blocklist that dives straight into another list' do
      node = parse(:subsection, <<EOS
        (1) here's my really cool list,
        (a) one
        (b) (i) single
        (ii) double
EOS
                  )
      node.statement.content.text_value.should == "here's my really cool list,"
      node.blocklist.elements.first.num.should == "(a)"
      node.blocklist.elements.first.content.should == "one"
      node.blocklist.elements[1].num.should == "(b)"
      node.blocklist.elements[1].content.should be_nil
      node.blocklist.elements[2].num.should == "(i)"
      node.blocklist.elements[2].content.should == "single"
      to_xml(node, "").should == '<subsection id="1">
  <num>(1)</num>
  <content>
    <blockList id="1.list0">
      <listIntroduction>here\'s my really cool list,</listIntroduction>
      <item id="1.list0.a">
        <num>(a)</num>
        <p>one</p>
      </item>
      <item id="1.list0.b">
        <num>(b)</num>
      </item>
      <item id="1.list0.i">
        <num>(i)</num>
        <p>single</p>
      </item>
      <item id="1.list0.ii">
        <num>(ii)</num>
        <p>double</p>
      </item>
    </blockList>
  </content>
</subsection>'
    end

    context 'dotted numbers' do
      it 'should handle dotted number subsection numbers' do
        node = parse :subsection, <<EOS
          9.9. foo
EOS
        node.statement.content.text_value.should == "foo"
        node.statement.num.should == "9.9"
      end

      it 'should handle dotted number sublists' do
        node = parse(:subsection, <<EOS
          9.9 foo
          9.9.1 item1
          9.9.2 item2
          9.9.2.1 item3
EOS
                    )
        node.statement.content.text_value.should == "foo"
        node.blocklist.elements.first.num.should == "9.9.1"
        node.blocklist.elements.first.content.should == "item1"

        node.blocklist.elements[2].num.should == "9.9.2.1"
        node.blocklist.elements[2].content.should == "item3"
      end
    end
  end

  #-------------------------------------------------------------------------------
  # Remarks

  describe 'remark' do
    it 'should handle a plain remark' do
      node = parse :subsection, <<EOS
      [[Section 2 amended by Act 23 of 2004]]
EOS
      to_xml(node, "").should == '<subsection id="subsection-0">
  <content>
    <p>
      <remark status="editorial">[Section 2 amended by Act 23 of 2004]</remark>
    </p>
  </content>
</subsection>'
    end

    it 'should handle an inline remark at the end of a sentence' do
      node = parse :subsection, <<EOS
      This statement has an inline remark. [[Section 2 amended by Act 23 of 2004]]
EOS
      to_xml(node, "").should == '<subsection id="subsection-0">
  <content>
    <p>This statement has an inline remark. <remark status="editorial">[Section 2 amended by Act 23 of 2004]</remark></p>
  </content>
</subsection>'
    end

    it 'should handle an inline remark mid-way through' do
      node = parse :subsection, <<EOS
      (1) This statement has an inline remark. [[Section 2 amended by Act 23 of 2004]] And now some more.
EOS
      to_xml(node, "").should == '<subsection id="1">
  <num>(1)</num>
  <content>
    <p>This statement has an inline remark. <remark status="editorial">[Section 2 amended by Act 23 of 2004]</remark> And now some more.</p>
  </content>
</subsection>'
    end

    it 'should handle many inline remarks' do
      node = parse :subsection, <<EOS
      This statement has an inline remark. [[Section 2 amended by Act 23 of 2004]]. And now some more. [[Another remark]] [[and another]]
EOS
      to_xml(node, "").should == '<subsection id="subsection-0">
  <content>
    <p>This statement has an inline remark. <remark status="editorial">[Section 2 amended by Act 23 of 2004]</remark>. And now some more. <remark status="editorial">[Another remark]</remark> <remark status="editorial">[and another]</remark></p>
  </content>
</subsection>'
    end

    it 'should handle a remark in a section' do
      node = parse :section, <<EOS
      1. Section title
      Some text is a long line.

      [[Section 1 amended by Act 23 of 2004]]
EOS
      to_xml(node).should == '<section id="section-1">
  <num>1.</num>
  <heading>Section title</heading>
  <subsection id="section-1.subsection-0">
    <content>
      <p>Some text is a long line.</p>
    </content>
  </subsection>
  <subsection id="section-1.subsection-1">
    <content>
      <p>
        <remark status="editorial">[Section 1 amended by Act 23 of 2004]</remark>
      </p>
    </content>
  </subsection>
</section>'
    end

    it 'should handle a remark in a schedule' do
      node = parse :schedule, <<EOS
      Schedule 1
      A Title

      [[Schedule 1 added by Act 23 of 2004]]

      Some content
EOS

      today = Time.now.strftime('%Y-%m-%d')
      to_xml(node, "").should == '<doc name="schedule1">
  <meta>
    <identification source="#slaw">
      <FRBRWork>
        <FRBRthis value="/za/act/1980/01/schedule1"/>
        <FRBRuri value="/za/act/1980/01"/>
        <FRBRalias value="Schedule 1"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRcountry value="za"/>
      </FRBRWork>
      <FRBRExpression>
        <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRlanguage language="eng"/>
      </FRBRExpression>
      <FRBRManifestation>
        <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="' + today + '" name="Generation"/>
        <FRBRauthor href="#slaw"/>
      </FRBRManifestation>
    </identification>
  </meta>
  <mainBody>
    <article id="schedule-1">
      <heading>A Title</heading>
      <content>
        <p>
          <remark status="editorial">[Schedule 1 added by Act 23 of 2004]</remark>
        </p>
        <p>Some content</p>
      </content>
    </article>
  </mainBody>
</doc>'
    end
  end

  #-------------------------------------------------------------------------------
  # Numbered statements

  describe 'numbered_statement' do
    it 'should handle basic numbered statements' do
      should_parse :numbered_statement, '(1) foo bar'
      should_parse :numbered_statement, '(1a) foo bar'
    end
  end

  #-------------------------------------------------------------------------------
  # Preface

  context 'preface' do
    it 'should consider any text at the start to be preface' do
      node = parse :act, <<EOS
foo
bar
(1) stuff
(2) more stuff
baz
1. Section
(1) hello
EOS

      node.preface.text_value.should == "foo
bar
(1) stuff
(2) more stuff
baz
"
      to_xml(node.preface).should == '<preface>
  <p>foo</p>
  <p>bar</p>
  <p>(1) stuff</p>
  <p>(2) more stuff</p>
  <p>baz</p>
</preface>'

      today = Time.now.strftime('%Y-%m-%d')
      to_xml(node, "").should == '<act contains="originalVersion">
  <meta>
    <identification source="#slaw">
      <FRBRWork>
        <FRBRthis value="/za/act/1980/01/main"/>
        <FRBRuri value="/za/act/1980/01"/>
        <FRBRalias value="Short Title"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRcountry value="za"/>
      </FRBRWork>
      <FRBRExpression>
        <FRBRthis value="/za/act/1980/01/eng@/main"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRlanguage language="eng"/>
      </FRBRExpression>
      <FRBRManifestation>
        <FRBRthis value="/za/act/1980/01/eng@/main"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="' + today + '" name="Generation"/>
        <FRBRauthor href="#slaw"/>
      </FRBRManifestation>
    </identification>
    <references source="#this">
      <TLCOrganization id="slaw" href="https://github.com/longhotsummer/slaw" showAs="Slaw"/>
      <TLCOrganization id="council" href="/ontology/organization/za/council" showAs="Council"/>
    </references>
  </meta>
  <preface>
    <p>foo</p>
    <p>bar</p>
    <p>(1) stuff</p>
    <p>(2) more stuff</p>
    <p>baz</p>
  </preface>
  <body>
    <section id="section-1">
      <num>1.</num>
      <heading>Section</heading>
      <subsection id="section-1.1">
        <num>(1)</num>
        <content>
          <p>hello</p>
        </content>
      </subsection>
    </section>
  </body>
</act>'
    end

    it 'should support an optional preface' do
      node = parse :act, <<EOS
PREFACE
foo
1. Section
(1) hello
EOS

      node.preface.text_value.should == "PREFACE\nfoo\n"
      to_xml(node.preface).should == '<preface>
  <p>foo</p>
</preface>'
    end

    it 'should support remarks in the preface' do
      node = parse :act, <<EOS
PREFACE

[[remark]]

foo

[[ another remark]]

1. Section
(1) hello
EOS

      to_xml(node.preface).should == '<preface>
  <p>
    <remark status="editorial">[remark]</remark>
  </p>
  <p>foo</p>
  <p>
    <remark status="editorial">[ another remark]</remark>
  </p>
</preface>'
    end

    it 'should support no preface' do
      node = parse :act, <<EOS
1. Section
bar
EOS

      node.preface.text_value.should == ""
    end

    it 'should support prefaces and preambles' do
      node = parse :act, <<EOS
this is in the preface

PREAMBLE

this is in the preamble

1. Section
(1) hello
EOS

      to_xml(node.preface).should == '<preface>
  <p>this is in the preface</p>
</preface>'
      to_xml(node.preamble).should == '<preamble>
  <p>this is in the preamble</p>
</preamble>'
    end

    it 'should support prefaces and preambles' do
      node = parse :act, <<EOS
PREFACE
this is in the preface

PREAMBLE
this is in the preamble

1. Section
(1) hello
EOS

      to_xml(node.preface).should == '<preface>
  <p>this is in the preface</p>
</preface>'
      to_xml(node.preamble).should == '<preamble>
  <p>this is in the preamble</p>
</preamble>'
    end
  end

  #-------------------------------------------------------------------------------
  # Preamble

  context 'preamble' do
    it 'should support an optional preamble' do
      node = parse :act, <<EOS
PREAMBLE
foo
1. Section
(1) hello
EOS

      node.preamble.text_value.should == "PREAMBLE\nfoo\n"
      to_xml(node.preamble).should == '<preamble>
  <p>foo</p>
</preamble>'
    end

    it 'should support remarks in the preamble' do
      node = parse :act, <<EOS
PREAMBLE

[[remark]]

foo

[[ another remark]]

1. Section
(1) hello
EOS

      to_xml(node.preamble).should == '<preamble>
  <p>
    <remark status="editorial">[remark]</remark>
  </p>
  <p>foo</p>
  <p>
    <remark status="editorial">[ another remark]</remark>
  </p>
</preamble>'
    end

    it 'should support no preamble' do
      node = parse :act, <<EOS
1. Section
bar
EOS

      node.elements.first.text_value.should == ""
    end
  end

  #-------------------------------------------------------------------------------
  # Sections

  context 'sections' do
    it 'should handle section numbers after title' do
      subject.parser.options = {section_number_after_title: true}
      node = parse :act, <<EOS
Section
1. (1) hello
EOS

      section = node.chapters.elements.first.parts.elements.first.sections.elements.first
      section.section_title.content.text_value.should == "Section"
      section.section_title.section_title_prefix.number_letter.text_value.should == "1"
    end

    it 'should handle section numbers before title' do
      subject.parser.options = {section_number_after_title: false}
      node = parse :act, <<EOS
1. Section
(1) hello
EOS

      section = node.chapters.elements.first.parts.elements.first.sections.elements.first
      section.section_title.title.should == "Section"
      section.section_title.num.should == "1"
    end

    it 'should handle section numbers without a dot' do
      subject.parser.options = {section_number_after_title: false}
      node = parse :act, <<EOS
1 A section
(1) hello
2 Another section
(2) Another line
EOS

      section = node.chapters.elements.first.parts.elements.first.sections.elements.first
      section.section_title.title.should == "A section"
      section.section_title.num.should == "1"

      section = node.chapters.elements[0].parts.elements.first.sections.elements[1]
      section.section_title.title.should == "Another section"
      section.section_title.num.should == "2"
    end

    it 'should handle sections without titles and with subsections' do
      subject.parser.options = {section_number_after_title: false}
      node = parse :act, <<EOS
10. (1) Transporters must remove medical waste.
(2) Without limiting generality, stuff.
EOS

      section = node.chapters.elements.first.parts.elements.first.sections.elements.first
      section.section_title.title.should == ""
      section.section_title.num.should == "10"
      section.subsections.elements[0].statement.num.should == "(1)"
      section.subsections.elements[0].statement.content.text_value.should == "Transporters must remove medical waste."
    end
  end

  #-------------------------------------------------------------------------------
  # schedules

  context 'schedules' do
    it 'should handle a simple schedule' do
      node = parse :schedules, <<EOS
Schedule
Subject to approval in terms of this By-Law, the erection:
1. Foo
2. Bar
EOS

      sched = node.schedules.elements[0]
      sched.schedule_heading.schedule_heading_prefix.text_value.should == "Schedule"
      sched.statements.elements[0].clauses.text_value.should == "Subject to approval in terms of this By-Law, the erection:"
      sched.statements.elements[1].clauses.text_value.should == "1. Foo"
      sched.statements.elements[2].clauses.text_value.should == "2. Bar"
    end

    it 'should handle many schedules' do
      node = parse :schedules, <<EOS
Schedule "1"
A Title
1. Foo
2. Bar
Schedule 2
Another Title
Baz
Boom
EOS

      sched = node.schedules.elements[0]
      sched.schedule_heading.schedule_heading_prefix.text_value.should == "Schedule"
      sched.schedule_heading.schedule_title.content.text_value.should == "A Title"
      sched.schedule_heading.num.text_value.should == "1"
      sched.statements.elements[0].clauses.text_value.should == "1. Foo"
      sched.statements.elements[1].clauses.text_value.should == "2. Bar"

      sched = node.schedules.elements[1]
      sched.schedule_heading.schedule_heading_prefix.text_value.should == "Schedule"
      sched.schedule_heading.schedule_title.content.text_value.should == "Another Title"
      sched.schedule_heading.num.text_value.should == "2"
      sched.statements.elements[0].clauses.text_value.should == "Baz"
      sched.statements.elements[1].clauses.text_value.should == "Boom"
    end

    it 'should serialise many schedules correctly' do
      node = parse :schedules, <<EOS
Schedule "2"
A Title
1. Foo
2. Bar
Schedule 3
Another Title
Baz
Boom
EOS

      s = to_xml(node)
      today = Time.now.strftime('%Y-%m-%d')
      s.should == <<EOS
<components>
  <component id="component-1">
    <doc name="schedule2">
      <meta>
        <identification source="#slaw">
          <FRBRWork>
            <FRBRthis value="/za/act/1980/01/schedule2"/>
            <FRBRuri value="/za/act/1980/01"/>
            <FRBRalias value="Schedule 2"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRcountry value="za"/>
          </FRBRWork>
          <FRBRExpression>
            <FRBRthis value="/za/act/1980/01/eng@/schedule2"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRlanguage language="eng"/>
          </FRBRExpression>
          <FRBRManifestation>
            <FRBRthis value="/za/act/1980/01/eng@/schedule2"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="#{today}" name="Generation"/>
            <FRBRauthor href="#slaw"/>
          </FRBRManifestation>
        </identification>
      </meta>
      <mainBody>
        <article id="schedule-2">
          <heading>A Title</heading>
          <content>
            <p>1. Foo</p>
            <p>2. Bar</p>
          </content>
        </article>
      </mainBody>
    </doc>
  </component>
  <component id="component-2">
    <doc name="schedule3">
      <meta>
        <identification source="#slaw">
          <FRBRWork>
            <FRBRthis value="/za/act/1980/01/schedule3"/>
            <FRBRuri value="/za/act/1980/01"/>
            <FRBRalias value="Schedule 3"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRcountry value="za"/>
          </FRBRWork>
          <FRBRExpression>
            <FRBRthis value="/za/act/1980/01/eng@/schedule3"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRlanguage language="eng"/>
          </FRBRExpression>
          <FRBRManifestation>
            <FRBRthis value="/za/act/1980/01/eng@/schedule3"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="#{today}" name="Generation"/>
            <FRBRauthor href="#slaw"/>
          </FRBRManifestation>
        </identification>
      </meta>
      <mainBody>
        <article id="schedule-3">
          <heading>Another Title</heading>
          <content>
            <p>Baz</p>
            <p>Boom</p>
          </content>
        </article>
      </mainBody>
    </doc>
  </component>
</components>
EOS
    .strip

    end

    it 'should serialise a single schedule without a heading' do
      node = parse :schedules, <<EOS
Schedule "1"
Other than as is set out hereinbelow, no signs other than locality bound signs, temporary signs including loose portable sign, estate agents signs, newspaper headline posters and posters (the erection of which must comply with the appropriate schedules pertinent thereto) shall be erected on Municipal owned land.
1. Foo
2. Bar
EOS

      s = to_xml(node)
      today = Time.now.strftime('%Y-%m-%d')
      s.should == <<EOS
<components>
  <component id="component-1">
    <doc name="schedule1">
      <meta>
        <identification source="#slaw">
          <FRBRWork>
            <FRBRthis value="/za/act/1980/01/schedule1"/>
            <FRBRuri value="/za/act/1980/01"/>
            <FRBRalias value="Schedule 1"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRcountry value="za"/>
          </FRBRWork>
          <FRBRExpression>
            <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="1980-01-01" name="Generation"/>
            <FRBRauthor href="#council"/>
            <FRBRlanguage language="eng"/>
          </FRBRExpression>
          <FRBRManifestation>
            <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
            <FRBRuri value="/za/act/1980/01/eng@"/>
            <FRBRdate date="#{today}" name="Generation"/>
            <FRBRauthor href="#slaw"/>
          </FRBRManifestation>
        </identification>
      </meta>
      <mainBody>
        <article id="schedule-1">
          <content>
            <p>Other than as is set out hereinbelow, no signs other than locality bound signs, temporary signs including loose portable sign, estate agents signs, newspaper headline posters and posters (the erection of which must comply with the appropriate schedules pertinent thereto) shall be erected on Municipal owned land.</p>
            <p>1. Foo</p>
            <p>2. Bar</p>
          </content>
        </article>
      </mainBody>
    </doc>
  </component>
</components>
EOS
      .strip
    end
  end

  describe 'tables' do
    it 'should parse basic tables' do
      node = parse :table, <<EOS
{|
| r1c1
| r1c2
|-
| r2c1
| r2c2
|}
EOS

      node.text_value.should == "{|\n| r1c1\n| r1c2\n|-\n| r2c1\n| r2c2\n|}\n"
      to_xml(node, "prefix.").should == '<table id="prefix.table0"><tr><td><p>r1c1</p></td>
<td><p>r1c2</p></td></tr>
<tr><td><p>r2c1</p></td>
<td><p>r2c2</p></td></tr></table>'
    end

    it 'should parse a table in a section' do
      node = parse :section, <<EOS
10. A section title

Heres a table:

{|
| r1c1
| r1c2
|-
| r2c1
| r2c2
|}
EOS

      xml = to_xml(node)
      xml.should == '<section id="section-10">
  <num>10.</num>
  <heading>A section title</heading>
  <subsection id="section-10.subsection-0">
    <content>
      <p>Heres a table:</p>
    </content>
  </subsection>
  <subsection id="section-10.subsection-1">
    <content>
      <table id="section-10.subsection-1.table0"><tr><td><p>r1c1</p></td>
<td><p>r1c2</p></td></tr>
<tr><td><p>r2c1</p></td>
<td><p>r2c2</p></td></tr></table>
    </content>
  </subsection>
</section>'
    end

    it 'should parse a table in a schedule' do
      node = parse :schedule, <<EOS
Schedule 1

Heres a table:

{|
| r1c1
| r1c2
|-
| r2c1
| r2c2
|}
EOS

      xml = to_xml(node, "")
      today = Time.now.strftime('%Y-%m-%d')
      xml.should == '<doc name="schedule1">
  <meta>
    <identification source="#slaw">
      <FRBRWork>
        <FRBRthis value="/za/act/1980/01/schedule1"/>
        <FRBRuri value="/za/act/1980/01"/>
        <FRBRalias value="Schedule 1"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRcountry value="za"/>
      </FRBRWork>
      <FRBRExpression>
        <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="1980-01-01" name="Generation"/>
        <FRBRauthor href="#council"/>
        <FRBRlanguage language="eng"/>
      </FRBRExpression>
      <FRBRManifestation>
        <FRBRthis value="/za/act/1980/01/eng@/schedule1"/>
        <FRBRuri value="/za/act/1980/01/eng@"/>
        <FRBRdate date="' + today + '" name="Generation"/>
        <FRBRauthor href="#slaw"/>
      </FRBRManifestation>
    </identification>
  </meta>
  <mainBody>
    <article id="schedule-1">
      <content>
        <p>Heres a table:</p>
        <table id="schedule-1.table0"><tr><td><p>r1c1</p></td>
<td><p>r1c2</p></td></tr>
<tr><td><p>r2c1</p></td>
<td><p>r2c2</p></td></tr></table>
      </content>
    </article>
  </mainBody>
</doc>'
    end
  end

  #-------------------------------------------------------------------------------
  # clauses

  context 'clauses' do
    it 'should handle a simple clause' do
      node = parse :clauses, "simple text"
      node.text_value.should == "simple text"
    end

    it 'should handle a clause with a remark' do
      node = parse :clauses, "simple [[remark]]. text"
      node.text_value.should == "simple [[remark]]. text"
      node.elements[1].elements.first.is_a?(Slaw::ZA::Act::Remark).should be_true

      node = parse :clauses, "simple [[remark]][[another]] text"
      node.text_value.should == "simple [[remark]][[another]] text"
      node.elements[1].elements.first.is_a?(Slaw::ZA::Act::Remark).should be_true
      node.elements[2].elements.first.is_a?(Slaw::ZA::Act::Remark).should be_true
    end
  end
end
