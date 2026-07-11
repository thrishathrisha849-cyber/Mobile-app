-- 1. Create the posts table
CREATE TABLE posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(255) NOT NULL,
  time VARCHAR(100) DEFAULT 'Just now',
  badge VARCHAR(100),
  badge_color VARCHAR(50) DEFAULT '#CC0000',
  avatar_url TEXT,
  content TEXT NOT NULL,
  has_video BOOLEAN DEFAULT FALSE,
  video_thumbnail TEXT,
  has_images BOOLEAN DEFAULT FALSE,
  images TEXT[] DEFAULT '{}',
  likes INTEGER DEFAULT 0,
  comments INTEGER DEFAULT 0,
  shares INTEGER DEFAULT 0,
  is_liked BOOLEAN DEFAULT FALSE,
  is_bookmarked BOOLEAN DEFAULT FALSE,
  is_following BOOLEAN DEFAULT FALSE,
  is_mentor BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Insert initial community post data
INSERT INTO posts (name, role, time, badge, badge_color, avatar_url, content, has_video, video_thumbnail, likes, comments, shares, is_liked, is_bookmarked, is_following, is_mentor)
VALUES 
(
  'Arun Prakash',
  'Business Owner • Chennai',
  '2h ago',
  '10X Growth',
  '#CC0000',
  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
  'Before joining Tamil Business Tribe, I was struggling to get consistent clients. Within 6 months, my business grew 10X! The strategies, accountability and support from the coaches are unmatched. 🙏',
  true,
  'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600',
  124,
  18,
  6,
  true,
  false,
  true,
  false
),
(
  'Kavitha R',
  'Boutique Owner • Coimbatore',
  '5h ago',
  '5X Growth',
  '#D4AF37',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
  'From barely making ₹20K/month to ₹1L+/month! 🎯 The business framework and marketing strategies taught here are pure gold. Thank you Tamil Business Tribe! ❤️',
  false,
  NULL,
  96,
  12,
  4,
  true,
  true,
  false,
  false
),
(
  'Suresh D',
  'Digital Marketer • Madurai',
  '1d ago',
  'Strategy',
  '#CC0000',
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
  'The way of coaching here is next level. They don''t just teach, they implement with us. Weekly calls, task tracking, and real feedback - this is why I stay consistent! 💪',
  false,
  NULL,
  64,
  9,
  3,
  true,
  false,
  false,
  true
);

INSERT INTO posts (name, role, time, badge, badge_color, avatar_url, content, has_images, images, likes, comments, shares, is_liked, is_bookmarked, is_following, is_mentor)
VALUES
(
  'Nandhini S',
  'Handmade Jewelry Business • Erode',
  '1d ago',
  '10X Growth',
  '#CC0000',
  'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
  'Breakthrough moment! 🎉 Hit my highest sales month ever. From local sales to pan India orders. The community support and strategies are powerful!',
  true,
  ARRAY['special_text_card', 'https://images.unsplash.com/photo-1617038260897-41a1f14a8ca0?w=300', 'https://images.unsplash.com/photo-1538168191891-6383b4724016?w=300'],
  112,
  15,
  5,
  true,
  false,
  true,
  false
);

INSERT INTO posts (name, role, time, badge, badge_color, avatar_url, content, has_video, video_thumbnail, likes, comments, shares, is_liked, is_bookmarked, is_following, is_mentor)
VALUES 
(
  'Manikandan V',
  'IT Service Provider • Trichy',
  '1d ago',
  'Strategy',
  '#CC0000',
  'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
  'Implemented the client acquisition strategy and doubled my MRR in just 90 days. Systems + Execution = Results! 🔥',
  false,
  NULL,
  82,
  7,
  2,
  true,
  false,
  false,
  false
);
