# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

articles = [
  # Publish 状态的文章
  {
    title: "百年孤独",
    content: "《百年孤独》是加西亚·马尔克斯的代表作,讲述了布恩迪亚家族七代人的传奇故事。这部作品融合了现实与魔幻,展现了拉丁美洲的历史与文化。",
    status: "publish",
    slug: "百年孤独"
  },
  {
    title: "1984",
    content: "乔治·奥威尔的《1984》是一部著名的反乌托邦小说,描绘了一个极权主义社会。故事中的主角温斯顿·史密斯试图反抗这个压抑的制度,但最终失败。",
    status: "publish",
    slug: "1984"
  },
  {
    title: "三体",
    content: "刘慈欣的科幻小说《三体》讲述了人类文明与三体文明的复杂互动。这部作品探讨了宇宙文明的发展、科技进步带来的影响以及人性的多面性。",
    status: "publish",
    slug: "三体"
  },
  {
    title: "红楼梦",
    content: "《红楼梦》是中国古典文学巅峰之作,描绘了贾宝玉和林黛玉的爱情故事,以及贾府的兴衰。",
    status: "publish",
    slug: "红楼梦"
  },
  {
    title: "Pride and Prejudice",
    content: "Jane Austen's 'Pride and Prejudice' is a classic romance novel that explores themes of love, class, and societal expectations in 19th century England.",
    status: "publish",
    slug: "pride-and-prejudice"
  },
  {
    title: "平凡的世界",
    content: "路遥的《平凡的世界》描述了陕北农村青年孙少平和孙少安的人生历程,展现了中国农村的变迁。",
    status: "publish",
    slug: "平凡的世界"
  },
  {
    title: "To Kill a Mockingbird",
    content: "Harper Lee's 'To Kill a Mockingbird' addresses issues of racial injustice and moral growth in the American South through the eyes of young Scout Finch.",
    status: "publish",
    slug: "to-kill-a-mockingbird"
  },
  {
    title: "围城",
    content: "钱钟书的《围城》以幽默风趣的笔触描绘了1930年代中国知识分子的生活,探讨了婚姻和生活的困境。",
    status: "publish",
    slug: "围城"
  },
  {
    title: "白鹿原",
    content: "陈忠实的《白鹿原》以陕西关中地区为背景,描绘了白氏和鹿氏两大家族的恩怨,展现了中国农村的历史变迁。",
    status: "publish",
    slug: "白鹿原"
  },
  {
    title: "One Hundred Years of Solitude",
    content: "Gabriel García Márquez's 'One Hundred Years of Solitude' tells the multi-generational story of the Buendía family, blending magical realism with the history of Colombia.",
    status: "publish",
    slug: "one-hundred-years-of-solitude"
  },
  {
    title: "边城",
    content: "沈从文的《边城》以湘西边城为背景,讲述了少女翠翠的爱情故事,展现了湘西的风土人情。",
    status: "publish",
    slug: "边城"
  },
  {
    title: "Brave New World",
    content: "Aldous Huxley's 'Brave New World' is a dystopian novel that explores a genetically engineered future society, questioning the price of stability and happiness.",
    status: "publish",
    slug: "brave-new-world"
  },
  {
    title: "The Great Gatsby",
    content: "F. Scott Fitzgerald's 'The Great Gatsby' is a tragic love story set in the 1920s, exploring themes of the American Dream and the pursuit of happiness.",
    status: "publish",
    slug: "the-great-gatsby"
  },
  {
    title: "The Picture of Dorian Gray",
    content: "Oscar Wilde's 'The Picture of Dorian Gray' is a Gothic novel that explores the themes of beauty, morality, and the loss of innocence.",
    status: "publish",
    slug: "the-picture-of-dorian-gray"
  },



  # Draft 状态的文章
  {
    title: "哈利·波特与魔法石",
    content: "J.K.罗琳的《哈利·波特与魔法石》是魔幻文学系列的开篇之作，讲述了年轻巫师哈利·波特在霍格沃茨魔法学校的冒险故事。",
    status: "draft",
    slug: "哈利波特与魔法石"
  },
  {
    title: "指环王：魔戒再现",
    content: "J.R.R.托尔金的《指环王：魔戒再现》是一部史诗奇幻小说，描绘了中土世界的宏大冒险，以及对抗邪恶力量的英雄之旅。",
    status: "draft",
    slug: "指环王魔戒再现"
  },
  {
    title: "小王子",
    content: "安托万·德·圣-埃克苏佩里的《小王子》是一部充满哲理的儿童文学作品，探讨了友谊、爱情和人生的意义。",
    status: "draft",
    slug: "小王子"
  },
  {
    title: "西游记",
    content: "《西游记》是中国四大名著之一,讲述了唐僧师徒四人西天取经的神话故事。",
    status: "draft",
    slug: "西游记"
  },
  {
    title: "茶馆",
    content: "老舍的《茶馆》以北京的一家茶馆为背景,展现了半个世纪的社会变迁和各色人物的命运。",
    status: "draft",
    slug: "茶馆"
  },
  {
    title: "1984",
    content: "George Orwell's '1984' is a dystopian novel set in a totalitarian society, exploring themes of government surveillance, censorship, and the manipulation of truth.",
    status: "draft",
    slug: "nineteen-eighty-four"
  },
  {
    title: "骆驼祥子",
    content: "老舍的《骆驼祥子》描述了北京车夫祥子的悲惨命运,反映了旧社会底层人民的艰难生活。",
    status: "draft",
    slug: "骆驼祥子"
  },
  {
    title: "The Lord of the Rings",
    content: "J.R.R. Tolkien's 'The Lord of the Rings' is an epic high-fantasy novel that follows the quest to destroy the One Ring and defeat the Dark Lord Sauron.",
    status: "draft",
    slug: "the-lord-of-the-rings"
  },
  {
    title: "子夜",
    content: "茅盾的《子夜》描绘了1930年代上海的工商业社会,展现了民族资本主义的困境。",
    status: "draft",
    slug: "子夜"
  },
  {
    title: "The Chronicles of Narnia",
    content: "C.S. Lewis's 'The Chronicles of Narnia' is a series of fantasy novels that transport children to the magical world of Narnia, blending adventure with Christian themes.",
    status: "draft",
    slug: "the-chronicles-of-narnia"
  },
  {
    title: "家",
    content: "巴金的《家》是激流三部曲的第一部,描述了封建大家庭的没落,反映了五四运动前后的社会变革。",
    status: "draft",
    slug: "家"
  },
  {
    title: "The Hobbit",
    content: "J.R.R. Tolkien's 'The Hobbit' follows Bilbo Baggins on an adventure to help a group of dwarves reclaim their mountain home from a dragon.",
    status: "draft",
    slug: "the-hobbit"
  },
  {
    title: "The Catcher in the Rye",
    content: "J.D. Salinger's 'The Catcher in the Rye' follows the experiences of teenager Holden Caulfield in New York City, exploring themes of alienation and teenage angst.",
    status: "draft",
    slug: "the-catcher-in-the-rye"
  },

  # Trash 状态的文章
  {
    title: "活着",
    content: "余华的《活着》通过福贵的人生经历,展现了中国近现代史上普通人的命运。小说以冷静的笔触描绘了生命的顽强和人性的复杂。",
    status: "trash",
    slug: "活着"
  },
  {
    title: "霍乱时期的爱情",
    content: "加西亚·马尔克斯的《霍乱时期的爱情》是一部跨越半个多世纪的爱情史诗。小说讲述了费尔明诺·阿里萨和费梅娜·达萨之间复杂而持久的爱情故事。",
    status: "trash",
    slug: "霍乱时期的爱情"
  },
  {
    title: "追风筝的人",
    content: "卡勒德·胡赛尼的《追风筝的人》讲述了阿富汗少年阿米尔和哈桑之间复杂的友谊，以及赎罪与救赎的主题。",
    status: "trash",
    slug: "追风筝的人"
  },
  {
    title: "水浒传",
    content: "《水浒传》描述了108位好汉聚义梁山的故事,展现了宋代社会的矛盾和民间英雄的反抗精神。",
    status: "trash",
    slug: "水浒传"
  },
  {
    title: "Moby-Dick",
    content: "Herman Melville's 'Moby-Dick' tells the story of a whaling ship's crew on a quest for revenge against a giant white sperm whale, exploring themes of obsession and nature.",
    status: "trash",
    slug: "moby-dick"
  },
  {
    title: "三国演义",
    content: "《三国演义》是中国古典四大名著之一,描述了东汉末年到三国时期的历史故事,塑造了诸葛亮、关羽等经典人物形象。",
    status: "trash",
    slug: "三国演义"
  },
  {
    title: "The Odyssey",
    content: "Homer's 'The Odyssey' is an ancient Greek epic poem that follows Odysseus's long journey home after the Trojan War, facing numerous challenges and mythical creatures.",
    status: "trash",
    slug: "the-odyssey"
  },
  {
    title: "金瓶梅",
    content: "《金瓶梅》是中国文学史上第一部文人独立创作的长篇白话世情小说,以宋代为背景,描绘了市井生活和人性百态。",
    status: "trash",
    slug: "金瓶梅"
  },
  {
    title: "Don Quixote",
    content: "Miguel de Cervantes' 'Don Quixote' follows the adventures of a man who loses his sanity reading chivalric romances and decides to become a knight-errant.",
    status: "trash",
    slug: "don-quixote"
  },
  {
    title: "儒林外史",
    content: "吴敬梓的《儒林外史》以讽刺的笔调描绘了清代的文人生活,批评了科举制度和官场腐败。",
    status: "trash",
    slug: "儒林外史"
  },
  {
    title: "War and Peace",
    content: "Leo Tolstoy's 'War and Peace' is a historical novel that tells the story of five aristocratic families in Russia during the Napoleonic Era.",
    status: "trash",
    slug: "war-and-peace"
  },
  {
    title: "聊斋志异",
    content: "蒲松龄的《聊斋志异》是一部文言短篇小说集,以志怪的形式反映了当时的社会现实和人情世态。",
    status: "trash",
    slug: "聊斋志异"
  },
  {
    title: "Crime and Punishment",
    content: "Fyodor Dostoevsky's 'Crime and Punishment' explores the moral dilemmas of Raskolnikov, a poor ex-student in St. Petersburg who formulates a plan to kill an unscrupulous pawnbroker for her money.",
    status: "trash",
    slug: "crime-and-punishment"
  },
  {
    title: "The Adventures of Sherlock Holmes",
    content: "Arthur Conan Doyle's 'The Adventures of Sherlock Holmes' is a collection of short stories featuring the famous detective Sherlock Holmes and his sidekick Dr. John Watson.",
    status: "trash",
    slug: "the-adventures-of-sherlock-holmes"
  },

  # Page 状态的文章
  {
    title: "About",
    content: "About",
    status: "publish",
    slug: "about",
    is_page: true,
    page_order: 1
  },
  {
    title: "Projects",
    content: "Projects",
    status: "publish",
    slug: "projects",
    is_page: true,
    page_order: 2
  },
  {
    title: "Links",
    content: "Links",
    status: "draft",
    slug: "links",
    is_page: true,
    page_order: 3
  }
]

all_slugs = articles.map { |article| article[:slug] }
duplicate_slugs = all_slugs.group_by { |slug| slug }.select { |_, group| group.size > 1 }.keys
if duplicate_slugs.empty?
  puts "No duplicate slugs found."
else
  puts "Duplicate slugs found:"
  duplicate_slugs.each do |slug|
    puts "- #{slug}"
    articles.select { |article| article[:slug] == slug }.each do |article|
      puts "  * #{article[:title]} (status: #{article[:status]})"
    end
  end
end

# 清空现有的文章和 FTS 表
Article.delete_all
ActiveRecord::Base.connection.execute("DELETE FROM article_fts")

articles.each do |article_data|
  article = Article.new(
    title: article_data[:title],
    status: article_data[:status],
    slug: article_data[:slug],
    is_page: article_data[:is_page] || false,
    page_order: article_data[:page_order] || 0
  )
  article.content = article_data[:content]
  
  
  # 直接插入 FTS 数据
  sql = ActiveRecord::Base.sanitize_sql_array(
    [
      "INSERT INTO article_fts (rowid, title, content) VALUES (?, ?, ?)",
      article.id,
      article.title || "",
      article.content.to_plain_text
    ]
  )
  ActiveRecord::Base.connection.execute(sql)
  article.save!
end

puts "Added #{Article.count} articles!"
