import Foundation

struct StoryTemplate: Identifiable, Equatable {
    let id: UUID
    let title: String
    let coverIcon: String
    let description: String
    let coverGradient: [String]
    let pages: [String]
    let styleContext: String
    let category: String
    let isNew: Bool
    let isPro: Bool
    let learningTakeaway: String

    init(
        id: UUID = UUID(),
        title: String,
        coverIcon: String,
        description: String,
        coverGradient: [String] = ["FFD93D", "FF8C6B"],
        pages: [String],
        styleContext: String = "",
        category: String = "World",
        isNew: Bool = false,
        isPro: Bool = false,
        learningTakeaway: String = ""
    ) {
        self.id = id
        self.title = title
        self.coverIcon = coverIcon
        self.description = description
        self.coverGradient = coverGradient
        self.pages = pages
        self.styleContext = styleContext
        self.category = category
        self.isNew = isNew
        self.isPro = isPro
        self.learningTakeaway = learningTakeaway
    }

    static let allCategories = ["All", "World", "Feelings", "Learn", "Seasonal", "New"]
    static let categoryIcons: [String: String] = [
        "World": "globe",
        "Feelings": "heart.fill",
        "Learn": "leaf.fill",
        "Seasonal": "calendar",
        "New": "sparkle",
    ]

    static let samples: [StoryTemplate] = [
        // NEW THIS WEEK
        StoryTemplate(
            title: "The Brave Little Explorer",
            coverIcon: "mountain.2.fill",
            description: "A courage-building adventure through magical lands",
            coverGradient: ["FF8C6B", "E86D4A"],
            pages: [
                "Once upon a time, a little explorer set out on a grand adventure.",
                "The path ahead was dark and winding, but our hero pressed on bravely.",
                "A friendly owl appeared and offered wise advice for the journey.",
                "Together they crossed a sparkling river on stepping stones of light.",
                "At the mountain top, the explorer found the most beautiful sunrise.",
                "\"I did it!\" the little explorer cheered, feeling braver than ever.",
                "The owl smiled and said, \"The courage was inside you all along.\"",
                "And from that day on, nothing seemed too scary to try.",
            ],
            styleContext: "A warm adventure story about building courage and overcoming fears",
            category: "Feelings",
            isNew: true,
            learningTakeaway: "Courage isn't the absence of fear — it's taking that next step even when you're scared. Every small act of bravery builds confidence."
        ),
        StoryTemplate(
            title: "Starlight Bedtime",
            coverIcon: "moon.stars.fill",
            description: "A soothing bedtime story under the stars",
            coverGradient: ["A78BFA", "6366F1"],
            pages: [
                "The sun dipped below the horizon and the first star appeared.",
                "A gentle breeze carried the scent of lavender through the window.",
                "The moon peeked in and whispered, \"Time to rest, little one.\"",
                "Fluffy clouds shaped like bunnies drifted across the sky.",
                "Each star twinkled a soft lullaby just for you.",
                "The night wrapped everything in a warm, cozy blanket.",
                "\"Goodnight, world,\" you whispered, eyes growing heavy.",
                "And the stars kept watch as you drifted into sweet dreams.",
            ],
            styleContext: "A calming bedtime story with gentle imagery and a soothing tone",
            category: "Feelings",
            isNew: true,
            learningTakeaway: "A calm bedtime routine helps children feel safe and secure. The night sky is full of wonder, not things to fear."
        ),
        // THIS MONTH'S THEMES
        StoryTemplate(
            title: "The Friendship Garden",
            coverIcon: "leaf.fill",
            description: "Learning to share, grow, and make new friends",
            coverGradient: ["6BCB77", "4D96FF"],
            pages: [
                "In a sunny corner of the park, there was a magical garden.",
                "One day, a shy little seedling popped up all alone.",
                "A cheerful sunflower leaned over and said, \"Hi there, neighbor!\"",
                "Soon, more flowers joined — each one different and wonderful.",
                "They shared sunshine and rain, helping each other grow tall.",
                "When a storm came, they held on tight and stayed strong together.",
                "The garden became the most colorful place in the whole town.",
                "Because the best gardens — like the best friendships — grow with love.",
            ],
            styleContext: "A heartwarming story about friendship, sharing, and growing together",
            category: "Learn",
            learningTakeaway: "Friendships grow when we share, support each other, and celebrate our differences. Every person adds something unique."
        ),
        StoryTemplate(
            title: "Ocean Wonders",
            coverIcon: "water.waves",
            description: "Dive deep and discover the magic of the sea",
            coverGradient: ["4D96FF", "2563EB"],
            pages: [
                "Beneath the waves, a whole world sparkled with color and life.",
                "A curious little fish swam past coral castles and dancing seaweed.",
                "An old sea turtle smiled and said, \"Come, I'll show you around.\"",
                "They visited the glowing jellyfish who lit up like lanterns.",
                "A playful dolphin joined them, spinning through bubbles of light.",
                "Deep in a cave, they found a pearl that shimmered with every color.",
                "\"The ocean is full of secrets,\" the turtle said, \"if you look closely.\"",
                "And the little fish swam home, dreaming of tomorrow's adventure.",
            ],
            styleContext: "An imaginative underwater adventure full of wonder and discovery",
            category: "World",
            learningTakeaway: "The ocean covers most of our planet and is home to incredible creatures. Curiosity and respect for nature help us discover amazing things."
        ),
        StoryTemplate(
            title: "Rainy Day Magic",
            coverIcon: "cloud.rain.fill",
            description: "Finding joy and imagination on a rainy afternoon",
            coverGradient: ["94A3B8", "64748B"],
            pages: [
                "Pitter-patter, pitter-patter — rain tapped on the window all morning.",
                "\"I'm bored!\" said the little one, pressing their nose against the glass.",
                "But then a cardboard box in the corner began to glow…",
                "It became a spaceship! Then a castle! Then a submarine!",
                "Blankets turned into mountains, and pillows became clouds.",
                "The stuffed animals joined the adventure as loyal companions.",
                "By the time the rain stopped, the little one didn't even notice.",
                "\"Rainy days,\" they whispered, \"are actually the most magical.\"",
            ],
            styleContext: "A cozy indoor adventure celebrating creativity and imagination",
            category: "Feelings",
            learningTakeaway: "Boredom is the seed of creativity. When we use our imagination, even a simple cardboard box can become an entire world."
        ),
        StoryTemplate(
            title: "The Seasons Parade",
            coverIcon: "leaf.arrow.circlepath",
            description: "A journey through spring, summer, autumn, and winter",
            coverGradient: ["F59E0B", "DC2626"],
            pages: [
                "One morning, Spring tiptoed in wearing a crown of cherry blossoms.",
                "She painted the meadows green and woke up all the sleepy animals.",
                "Then Summer arrived with a big warm hug and golden sunshine.",
                "Everyone splashed in the lake and chased fireflies at dusk.",
                "Autumn waltzed in next, scattering leaves like confetti — red, gold, and orange.",
                "The squirrels gathered acorns and the pumpkins grew round and proud.",
                "Finally, Winter floated down in a soft blanket of snow.",
                "And all four seasons waved goodbye, promising to come again next year.",
            ],
            styleContext: "A lyrical journey through the four seasons with vivid imagery",
            category: "Seasonal",
            learningTakeaway: "Each season brings its own beauty and gifts. Change is natural, and there's something wonderful to enjoy in every time of year."
        ),
        StoryTemplate(
            title: "Counting Jungle",
            coverIcon: "bird.fill",
            description: "Learn numbers 1-10 with colorful jungle animals",
            coverGradient: ["10B981", "047857"],
            pages: [
                "1 happy monkey swung from vine to vine — wheee!",
                "2 tall giraffes stretched their necks to munch the highest leaves.",
                "3 playful parrots sang a rainbow song: \"Squawk, squawk, squawk!\"",
                "4 sneaky chameleons changed colors — can you spot them all?",
                "5 baby elephants splashed in the river, trunk to tail.",
                "6 stripy zebras galloped across the golden savanna.",
                "7 tiny tree frogs hopped from leaf to leaf — boing, boing!",
                "8 fireflies blinked on as the jungle sun went down.",
                "9 little stars peeked through the canopy above.",
                "And 10 sleepy animals curled up together. Goodnight, jungle!",
            ],
            styleContext: "A fun educational counting story set in a vibrant jungle",
            category: "Learn",
            isPro: true,
            learningTakeaway: "Counting is all around us! Spotting numbers in nature makes learning feel like play. Can you count the animals in your own backyard?"
        ),
    ]
}
